import { MessageDecoder, JsonDecoder } from "../decoder"
import { ChannelMessage } from "../channel-message";
import { Transport } from "./transport";
import { AsyncConfig } from "../async-config";
import { EventSourceController, EventSourcePlus } from "event-source-plus";
import { TransportError } from "./transport-error";
import { Utils } from "../utils";

export class SseTransport implements Transport {

    private actualToken;
    private eventSource: EventSourcePlus;
    private serializer: MessageDecoder;
    private errorCount = 0;
    private controller: EventSourceController;
    private tokenUpdated: boolean = false;

    private static readonly MAX_RETRY_INTERVAL = 6000;
    private static readonly SUCESS_STATUS = 299;

    public static create(config: AsyncConfig,
        handleMessage = (_message: ChannelMessage) => { },
        errorCallback = (_error: TransportError) => { },
        transport: typeof EventSourcePlus = EventSourcePlus): Transport {
        return new SseTransport(config, handleMessage, errorCallback, transport);
    }

    private constructor(private config: AsyncConfig,
        private handleMessage: (_message: ChannelMessage) => void,
        private errorCallback: (_error: TransportError) => void,
        private readonly transport: typeof EventSourcePlus) {
        this.serializer = new JsonDecoder();
        this.actualToken = config.channel_secret;
    }

    name(): string {
        return 'sse';
    }

    public connect(connectedCallback?: () => void): void {
        if (this.connected()) {
            console.debug('async-client. sse already created and open');
            return;
        }

        this.eventSource = new this.transport(this.sseUrl(), {
            headers: {
                Authorization: "Bearer " + this.actualToken,
            },
            maxRetryInterval: SseTransport.MAX_RETRY_INTERVAL,
            maxRetryCount: this.config.maxReconnectAttempts,
        });

        const self = this;
        self.controller = this.eventSource.listen({
            onMessage: (event) => {
                try {
                    const message = this.serializer.decode_sse(event.data)
                    if (message.event == ":n_token") {
                        self.actualToken = message.payload;
                        self.tokenUpdated = true;
                    }
                    this.errorCount = 0;
                    self.handleMessage(message);
                } catch (error) {
                    console.error('Error processing message:', error);
                }
            },
            async onResponse({ response }) {
                console.debug(`Sse client received status code: ${response.status}`);
                if (connectedCallback && response.status <= SseTransport.SUCESS_STATUS) {
                    self.tokenUpdated = false;
                    connectedCallback();
                }
            },
            async onResponseError({ request, response, error }) {
                self.errorCount++;
                console.debug(`[Sse response error]`, request, response.status, error);
                const body = await response.text();
                console.error('Sse response error:', body);
                let parsed;
                try {
                    parsed = JSON.parse(body);
                } catch (e) {
                    console.error('Error parsing response:', e);
                    parsed = { error: body };
                }
                const reason = Utils.extractReason(parsed.error);
                const stopRetries = response.status == 400 ||
                    response.status == 404 ||
                    (response.status === 401 && !self.tokenUpdated) ||
                    (response.status == 428 && reason < 3050);

                if (stopRetries || self.errorCount >= self.config.maxReconnectAttempts) {
                    console.log('async-client. sse stopping retries');
                    self.disconnect();
                    self.errorCallback({ origin: 'sse', code: 1, message: response.statusText + ' ' + body });
                } else if (response.status === 401) {
                    console.log('async-client. disconnecting because 401 and will retry with new token');
                    self.disconnect();
                    self.connect(connectedCallback);
                }
            },

            onRequestError(context) {
                console.error('Sse request error:', context.error.message);
            },
        });

        console.debug('async-client. sse connect() called')
    }

    public disconnect(): void {
        console.info('async-client. sse disconnect() called');
        if (!this.controller.signal.aborted) {
            this.controller.abort();
            console.debug('async-client. sse aborted');
        } else {
            console.debug('async-client. sse already aborted');
        }
    }

    public connected(): boolean {
        return this.eventSource && this.controller && !this.controller.signal.aborted;
    }

    // only for testing or internal

    public getDecoder(): MessageDecoder {
        return this.serializer;
    }

    private sseUrl(): string {
        let url = this.config.socket_url;
        if (url.startsWith('ws')) {
            url = url.replace('ws', 'http');
        }
        return `${url}/ext/sse?channel=${this.config.channel_ref}`;
    }
}


