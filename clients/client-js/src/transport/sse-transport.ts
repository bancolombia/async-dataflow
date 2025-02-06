import { JsonDecoder } from "../json-decoder";
import { MessageDecoder } from "../serializer"
import { ChannelMessage } from "../channel-message";
import { RetryTimer } from "../retry-timer";
import { Transport } from "./transport";
import { AsyncConfig } from "../async-config";
import { EventSourcePlus } from "event-source-plus";
import { TransportError } from "./transport-error";
import { Utils } from "../utils";

export class SseTransport implements Transport {

    private actualToken;
    private eventSource: EventSourcePlus;
    private serializer: MessageDecoder;
    private errorCount = 0;

    private readonly MAX_RETRY_INTERVAL = 6000;

    constructor(private config: AsyncConfig,
        private handleMessage = (_message: ChannelMessage) => { },
        private errorCallback = (_error: TransportError) => { }) {
        this.serializer = new JsonDecoder();
        this.actualToken = config.channel_secret;
    }

    public connect() {
        if (this.eventSource) { // TODO: Verify conditions
            console.debug('async-client. sse already created and open');
            return;
        }

        this.eventSource = new EventSourcePlus(this.sseUrl(), {
            // this value will remain the same for every request
            headers: {
                Authorization: "Bearer " + this.actualToken,
            },
            maxRetryInterval: this.MAX_RETRY_INTERVAL,
            maxRetryCount: this.config.maxReconnectAttempts,
        });

        const self = this;
        const controller = this.eventSource.listen({
            onMessage: (event) => {
                try {
                    const message = this.serializer.decode_sse(event.data)
                    if (message.event == ":n_token") {
                        this.actualToken = message.payload;
                    }
                    this.errorCount = 0;
                    self.handleMessage(message);
                } catch (error) {
                    console.error('Error parsing message:', error);
                }
            },
            async onResponse({ response }) {
                console.debug(`Sse client received status code: ${response.status}`);
            },
            async onResponseError({ request, response, error }) {
                self.errorCount++;
                console.debug(`[Sse response error]`, request, response.status, error);
                const body = await response.json();
                console.error('Sse response error:', body);
                const reason = Utils.extractReason(body.error);
                const stopRetries = response.status == 400 || response.status == 401 || (response.status == 428 && reason < 3050);
                if (stopRetries || self.errorCount > self.config.maxReconnectAttempts) {
                    console.log('async-client. sse stopping retries');
                    controller.abort();
                    self.errorCallback({ code: 1, message: response.statusText + ' ' + body.error });
                }
            },

            onRequestError(context) {
                console.error('Sse request error:', context);
            },
        });

        console.debug('async-client. sse connect() called')
    }

    public disconnect(): void {
        console.info('async-client. sse disconnect() called');
    }

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


