import { JsonDecoder } from "../json-decoder";
import { MessageDecoder } from "../serializer"
import { ChannelMessage } from "../channel-message";
import { RetryTimer } from "../retry-timer";
import { Protocol } from "../protocol";
import { Cache } from "../cache";
import { Transport } from "./transport";
import { AsyncConfig } from "../async-config";
import { EventSourcePlus } from "event-source-plus";

export class SseTransport implements Transport {

    private actualToken;
    private eventSource: EventSourcePlus;
    public isOpen: boolean = false;
    public isActive: boolean = false;
    private stateCallbacks = { open: [], close: [], error: [], message: [] }
    private bindings = [];
    private ref = 0;
    private pendingHeartbeatRef: string = null;
    private closeWasClean: boolean = false;
    private heartbeatTimer = null;
    private readonly heartbeatIntervalMs: number;
    private tearingDown: boolean = false;
    private reconnectTimer: RetryTimer;
    private serializer: MessageDecoder;
    private subProtocols: string[] = [Protocol.JSON]
    private cache: Cache;

    constructor(private config: AsyncConfig) {
        const intWindow = typeof window !== "undefined" ? window : null;
        this.serializer = new JsonDecoder();
        this.actualToken = config.channel_secret;
        if (!config.dedupCacheDisable) {
            this.cache = new Cache(config.dedupCacheMaxSize, config.dedupCacheTtl);
        } else {
            this.cache = undefined;
        }
        if (intWindow && (config.checkConnectionOnFocus || config.checkConnectionOnFocus === undefined)) {
            intWindow.addEventListener('focus', () => {
                if (!this.closeWasClean) {
                    this.connect();
                }
            });
        }
    }

    public connect() {
        if (this.eventSource) { // TODO: Verify conditions
            console.debug('async-client. sse already created and open');
            return;
        }

        this.eventSource = new EventSourcePlus(this.sseUrl(), {
            // this value will remain the same for every request
            headers: {
                Authorization: "Bearer " + this.config.channel_secret,
            },
        });
        
        this.eventSource.listen({
            onMessage: (event) => {
                console.log('Event received:', event);
                try {
                    const message = this.serializer.decode_sse(event.data)
                    console.log('Event parsed:', message);
                    if (message.event == ":n_token") {
                        this.actualToken = message.payload;
                    } 
                    this.handleMessage(message);
                } catch (error) {
                    console.error('Error parsing message:', error);
                }
            },
            async onResponse({ request, response, options }) {
                console.debug(`Sse client received status code: ${response.status}`);
            },
            async onResponseError({ request, response, options }) {
                console.debug(
                    `[Sse response error]`,
                    request,
                    response.status,
                    response.body,
                );
            },
        });
   
        this.isActive = true;
        
        console.debug('async-client. sse connect() called')
    }

    public listenEvent(eventName: string, callBack: (msg: any) => void) {
        this.bindings.push({ eventName, callBack });
    }

    public disconnect(): void {
        console.info('async-client. sse disconnect() called')
        this.closeWasClean = true;
        this.isActive = false;
        clearInterval(this.heartbeatTimer);
        this.reconnectTimer.reset();
        // this.socket.close(1000, "Client disconnect");
        console.info('async-client. disconnect() called end')
    }

    private handleMessage(message: ChannelMessage) {
        this.bindings
            .filter(handler => this.matchHandlerExpr(handler.eventName, message.event))
            .filter(_handler => this.deDupFilter(message.message_id))
            .forEach(handler => handler.callBack(message))
    }

    private matchHandlerExpr(eventExpr: string, actualEventName: string): boolean {
        if (eventExpr === actualEventName) return true;
        const regexString = '^' + eventExpr.replace(/\*/g, '([^.]+)').replace(/#/g, '([^.]+\\.?)+') + '$';
        return actualEventName.search(regexString) !== -1;
    }

    private deDupFilter(message_id: string): boolean {
        if (this.cache === undefined) {
            return true;
        } else if (this.cache.get(message_id) !== undefined) {
            console.debug(`async-client. Dedup filtering for message_id: ${message_id} applied.`);
            return false;
        } else {
            this.cache.save(message_id, '');
            return true;
        }
    }

    // private ackMessage(message: ChannelMessage) {
    //     if (this.socket.readyState != SocketState.CLOSING && this.socket.readyState != SocketState.CLOSED) {
    //         this.socket.send(`Ack::${message.message_id}`);
    //     }
    // }

    // private onSocketClose(event) {
    //     this.isActive = false;
    //     console.warn(`async-client. channel close: ${event.code} ${event.reason}`);
    //     clearInterval(this.heartbeatTimer)
    //     const reason = this.extractReason(event.reason);
    //     const shouldRetry = event.code > 1001 || (event.code == 1001 && reason >= 3050);

    //     if (!this.closeWasClean && shouldRetry && event.reason != 'Invalid token for channel') {
    //         console.log(`async-client. Scheduling reconnect, clean: ${this.closeWasClean}`)
    //         this.reconnectTimer.schedule()
    //     } else {
    //         this.stateCallbacks.close.forEach(callback => callback(event));
    //     }

    // }

    // private extractReason(reason): number {
    //     const reasonNumber = parseInt(reason);
    //     if (isNaN(reasonNumber)) {
    //         return 0;
    //     }
    //     return reasonNumber;
    // }

    public getDecoder(): MessageDecoder {
        return this.serializer;
    }

    private sseUrl(): string {
        return `${this.config.socket_url}?channel=${this.config.channel_ref}`;
    }

    // private teardown(callback?: () => void): void {
    //     if (this.tearingDown) return;
    //     this.tearingDown = true;
    //     if (!this.socket) {
    //         this.tearingDown = false;
    //         return callback && callback();
    //     }

    //     if (this.socket && this.socket.readyState != SocketState.CLOSED && this.socket.readyState != SocketState.CLOSING) {
    //         this.socket.close();
    //     }

    //     this.waitForSocketClosed(() => {
    //         if (this.socket) {
    //             this.socket.onclose = function () { } // noop
    //             this.socket = null
    //         }
    //         this.tearingDown = false;
    //         callback && callback()
    //     });

    // }
}


