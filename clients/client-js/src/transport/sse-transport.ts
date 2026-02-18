import { MessageDecoder, JsonDecoder } from "../decoder/index.js"
import { ChannelMessage } from "../channel-message.js";
import { Transport } from "./transport.js";
import { AsyncConfig } from "../async-config.js";
import { EventSourceController, EventSourcePlus } from "event-source-plus";
import { TransportError } from "./transport-error.js";
import { Utils } from "../utils.js";

export class SseTransport implements Transport {

    private actualToken;
    private readonly serializer: MessageDecoder;
    private errorCount = 0;
    private controller: EventSourceController;

    private static readonly MAX_RETRY_INTERVAL = 6000;
    private static readonly SUCESS_STATUS = 299;

    public static create(config: AsyncConfig,
        handleMessage = (_message: ChannelMessage) => { },
        errorCallback = (_error: TransportError) => { },
        transport: EventSourcePlus = null): Transport {
            return new SseTransport(config, handleMessage, errorCallback, transport);
        }

    private constructor(private readonly config: AsyncConfig,
        private readonly handleMessage: (_message: ChannelMessage) => void,
        private readonly errorCallback: (_error: TransportError) => void,
        private readonly transport:EventSourcePlus = null) {
        this.serializer = new JsonDecoder();
        this.actualToken = config.channel_secret;
        this.transport = transport || new EventSourcePlus(this.sseUrl(), {
            maxRetryInterval: SseTransport.MAX_RETRY_INTERVAL,
            maxRetryCount: this.config.maxReconnectAttempts,
        });
        console.debug('async-client. sse transport created with transport: ', transport);
    }

    name(): string {
        return 'sse';
    }

    public connect(connectedCallback?: () => void): void {
        if (this.connected()) {
            console.debug('async-client. sse already created and open');
            return;
        } else {
            console.debug('async-client. sse not connected, creating new EventSource');
        }

        this.controller = this.transport.listen({
            onMessage: (event) => {             
                try {
                    const message = this.serializer.decode_sse(event.data)
                    if (message.event == ":n_token") {
                        this.actualToken = message.payload;
                        console.debug('async-client. sse received new token = ', this.actualToken);
                    }
                    this.errorCount = 0;
                    this.handleMessage(message);
                } catch (error) {
                    console.error('Error processing message:', error);
                }
            },
            onRequest: ({ options }) => {
                options.headers.append("Authorization", "Bearer " + this.getToken());
            },
            async onResponse({ response }) {
                console.debug(`Sse client received status code: ${response.status}`);
                if (connectedCallback && response.status <= SseTransport.SUCESS_STATUS) {
                    connectedCallback();
                }
            },
            async onResponseError({ request, response, error }) {
                this.errorCount++;
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
                    (response.status == 401 && reason < 3050) ||
                    (response.status == 428 && reason < 3050);

                if (stopRetries || this.errorCount >= this.config.maxReconnectAttempts) {
                    console.log('async-client. sse stopping retries');
                    this.disconnect();
                    this.errorCallback({ origin: 'sse', code: 1, message: response.statusText + ' ' + body });
                } else if (response.status === 401) {
                    console.log('async-client. disconnecting because 401 and will retry with new token');
                    this.disconnect();
                    this.connect(connectedCallback);
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
        return this.transport && this.controller && !this.controller.signal.aborted;
    }

    public send(message: string): void {
        console.warn('async-client. sse transport does not support sending messages. Use the WebSocket transport for sending messages.');
    }

    // only for testing or internal
    public getDecoder(): MessageDecoder {
        return this.serializer;
    }

    private getToken(): string {
        return this.actualToken;
    }

    private sseUrl(): string {
        if (this.config.sse_url) {
            return `${this.config.sse_url}/ext/sse?channel=${this.config.channel_ref}`;
        }
        console.debug('async-client. sse config.sse_url not set, trying to compute from socket_url');
        // try to compute the SSE URL from the socket URL
        let url = this.config.socket_url;
        if (url.startsWith('ws')) {
            url = url.replace('ws', 'http');
        } else if (url.startsWith('wss')) {
            url = url.replace('wss', 'https');
        }
        return `${url}/ext/sse?channel=${this.config.channel_ref}`;
    }
}


