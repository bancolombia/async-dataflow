import { SseTransport } from "./transport/sse-transport";
import { WsTransport } from "./transport/ws-transport";
import { Transport } from "./transport/transport";
import { AsyncConfig } from "./async-config";
export class AsyncClient {

    private selectedTransport: Transport;
    
    constructor(private config: AsyncConfig, private readonly transport: any = null) {
        if (transport === null) {
            this.selectedTransport = new WsTransport(config);
        } else {
            this.selectedTransport = new SseTransport(config);
        }
    }

    public connect() {
        this.selectedTransport.connect();
    }

    public listenEvent(eventName: string, callBack: (msg: any) => void) {
        this.selectedTransport.listenEvent(eventName, callBack);
    }

    public disconnect(): void {
        this.selectedTransport.disconnect();
    }
}


