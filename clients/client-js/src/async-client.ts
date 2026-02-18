import { Transport, SseTransport, WsTransport, TransportError } from "./transport/index.js";
import { AsyncConfig } from "./async-config.js";
import { Cache } from "./cache.js";
import { ChannelMessage } from "./channel-message.js";
export class AsyncClient {
    private currentTransport: Transport;
    private currentTransportIndex: number = 0;
    private readonly bindings = [];
    private readonly cache: Cache = undefined;
    private closeWasClean: boolean = false;
    private retriesByTransport = 0;

    constructor(private readonly config: AsyncConfig, private readonly transports: Array<string> | null, private readonly mockTransport: any = null) {
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
            return WsTransport.create(this.config,
                (message: ChannelMessage) => this.handleMessage(message),
                (error: TransportError) => this.handleTransportError(error),
                this.mockTransport);
        } else if (transport === 'sse') {
            return SseTransport.create(this.config,
                (message: ChannelMessage) => this.handleMessage(message),
                (error: TransportError) => this.handleTransportError(error),
                this.mockTransport);
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

    public connected(): boolean {
        return this.currentTransport.connected();
    }

    // internal methods
    private handleMessage(message: ChannelMessage) {
        if (message.event == ":n_token") {
            console.debug('async-client. received new token');
            this.config.channel_secret = message.payload;
            return;
        }

        if (this.bindings.length === 0) {
            console.error(`async-client. No bindings defined. Discarding ALL messages.`);
            this.currentTransport.send(`no-bindings-defined-msgid[${message.message_id}]`);
            return;
        }
        
        const candidateBindings = this.bindings
            .filter(handler => this.matchHandlerExpr(handler.eventName, message.event));

        if (candidateBindings.length === 0) {
            console.debug(`async-client. No bindings found for event'${message.event}' with message_id: ${message.message_id}. Discarding message.`);
            this.currentTransport.send(`no-bindings-for[${message.event}]-msgid[${message.message_id}]`);
            return;
        } else {
            candidateBindings
                .filter(_handler => this.deDupFilter(message.message_id))
                .forEach(handler => handler.callBack(message))
        }
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
        console.debug(`async-client. hanldling transport error: `, error);
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

