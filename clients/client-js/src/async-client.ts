import { SseTransport } from "./transport/sse-transport";
import { WsTransport } from "./transport/ws-transport";
import { Transport } from "./transport/transport";
import { AsyncConfig } from "./async-config";
import { Cache } from "./cache";
import { TransportError } from "./transport/transport-error";
import { ChannelMessage } from "./channel-message";
export class AsyncClient {
    private currentTransport: Transport;
    private currentTransportIndex: number = 0;
    private bindings = [];
    private cache: Cache = undefined;
    private closeWasClean: boolean = false;
    private retriesByTransport = 0;

    constructor(private config: AsyncConfig, private transports: Array<string> | null) {
        if (!config.dedupCacheDisable) {
            this.cache = new Cache(config.dedupCacheMaxSize, config.dedupCacheTtl);
        }
        if (this.transports == null || this.transports.length == 0) {
            this.transports = ['ws', 'sse'];
        }
        this.currentTransport = this.getTransport();
        const intWindow = typeof window !== "undefined" ? window : null;
        if (intWindow && (config.checkConnectionOnFocus || config.checkConnectionOnFocus === undefined)) {
            intWindow.addEventListener('focus', () => {
                if (!this.closeWasClean) {
                    this.connect();
                }
            });
        }
    }

    private getTransport(): Transport {
        const transport = this.transports[this.currentTransportIndex];
        console.log('will instantiate transport: ', transport);
        if (transport === 'ws') {
            return new WsTransport(this.config,
                (message: ChannelMessage) => this.handleMessage(message),
                (error: TransportError) => this.handleTransportError(error));
        } else if (transport === 'sse') {
            return new SseTransport(this.config,
                (message: ChannelMessage) => this.handleMessage(message),
                (error: TransportError) => this.handleTransportError(error));
        }
        throw new Error('No transport available: ' + transport);
    }

    public connect() {
        this.closeWasClean = false;
        this.currentTransport.connect();
    }

    public listenEvent(eventName: string, callBack: (msg: any) => void) {
        this.bindings.push({ eventName, callBack });
    }

    public disconnect(): void {
        this.closeWasClean = true;
        this.currentTransport.disconnect();
    }

    // internal methods
    private handleMessage(message: ChannelMessage) {
        if (message.event == ":n_token") {
            this.config.channel_secret = message.payload;
        }
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

    private handleTransportError(error: TransportError) {
        if (error.code === 1 && error.origin == this.currentTransport.name()) {
            this.retriesByTransport++;
            this.currentTransport.disconnect();
            this.currentTransportIndex = (this.currentTransportIndex + 1) % this.transports.length;
            if (this.retriesByTransport <= this.config.maxReconnectAttempts) {
                this.currentTransport = this.getTransport();
                this.connect();
            } else {
                console.error('async-client. stopping transport retries for ', this.transports);
            }
        }
    }
}

