export interface Transport {
    connect() : void;
    listenEvent(eventName: string, callBack: (msg: any) => void) : void;
    disconnect(): void; 
}
