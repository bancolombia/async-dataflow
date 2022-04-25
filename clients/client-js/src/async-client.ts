import {JsonDecoder} from "./json-decoder";
import {MessageDecoder} from "./serializer"
import {ChannelMessage} from "./channel-message";
import {RetryTimer} from "./retry-timer";
import {BinaryDecoder} from "./binary-decoder";
import {Protocol} from "./protocol";

export class AsyncClient {

    private actualToken;
    private socket : WebSocket;
    public isOpen: boolean = false;
    public isActive: boolean = false;
    private stateCallbacks = {open: [], close: [], error: [], message: []}
    private bindings = [];
    private ref = 0;
    private pendingHeartbeatRef : string = null;
    private closeWasClean = false;
    private heartbeatTimer = null;
    private readonly heartbeatIntervalMs : number;
    private tearingDown : boolean = false;
    private reconnectTimer : RetryTimer;
    private serializer: MessageDecoder;
    private subProtocols: string[] = [Protocol.JSON]

    constructor(private config: AsyncConfig, private readonly transport : any = null) {
        const intWindow = typeof window !== "undefined" ? window : null;
        this.transport = transport || intWindow['WebSocket'];
        this.heartbeatIntervalMs = config.heartbeat_interval || 750;
        this.reconnectTimer = new RetryTimer(() => this.teardown(() => this.connect()));
        this.actualToken = config.channel_secret;
        console.log(config.enable_binary_transport)
        console.log(typeof TextDecoder)
        if (config.enable_binary_transport && typeof TextDecoder !== "undefined"){
            this.subProtocols.push(Protocol.BINARY)
        }
    }

    public connect(){
        if (this.socket) return;
        console.log("Subprotocols: ", this.subProtocols)
        this.socket = new this.transport(this.socketUrl(), this.subProtocols);
        this.socket.binaryType = "arraybuffer";
        this.socket.onopen     = (event) => this.onSocketOpen(event)
        this.socket.onerror    = error => this.onSocketError(error)
        this.socket.onmessage  = event => this.onSocketMessage(event)
        this.socket.onclose    = event => this.onSocketClose(event)
    }

    public listenEvent(eventName : string, callBack : Function)  {
        this.bindings.push({eventName, callBack});
    }

    public doOnSocketOpen(callback){
        this.stateCallbacks.open.push(callback)
    }

    private onSocketOpen(event) {
        this.selectSerializerForProtocol();
        this.isOpen = true;
        this.reconnectTimer.reset();
        this.resetHeartbeat();
        this.socket.send(`Auth::${this.actualToken}`)
        this.stateCallbacks.open.forEach((callback) => callback(event) );
    }

    private selectSerializerForProtocol() : void {
        if (this.socket.protocol == Protocol.BINARY){
            this.serializer = new BinaryDecoder();
        }else {
            this.serializer = new JsonDecoder();
        }
    }

    private onSocketError(event) {
        //
    }

    private onSocketMessage(event) {
        const message = this.serializer.decode(event)
        if (!this.isActive && message.event == "AuthOk"){
            this.isActive = true;
            console.log("#DBG5 change active to true!")
        }else if(message.event == ":hb" && message.correlation_id == this.pendingHeartbeatRef){
            this.pendingHeartbeatRef = null;
            console.log("#DBG4", `Clean HB: ${message.correlation_id}`)
        }else if(message.event == ":new_tkn"){
            this.actualToken = message.payload;
            this.ackMessage(message);
        }else if (this.isActive){
            this.ackMessage(message);
            this.handleMessage(message);
        }else {
            const txt = "Unexpected message before AuthOK";
            console.error(txt, message);
        }
    }

    // private push(message: ChannelMessage) {
    //     const data = Serializer.encode(message);
    //     this.socket.send(data);
    // }

    private sendHeartbeat(){
        if(!this.isActive){ return }
        console.log("#DBG4", `Active is: ${this.isActive}`)
        if(this.pendingHeartbeatRef){
            this.pendingHeartbeatRef = null
            const reason = "heartbeat timeout. Attempting to re-establish connection";
            console.log("transport", reason)
            this.abnormalClose(reason)
            return;
        }
        this.pendingHeartbeatRef = this.makeRef();
        console.log("#DBG4", `Hb is: ${this.pendingHeartbeatRef}`)
        this.socket.send(`hb::${this.pendingHeartbeatRef}`);
    }

    private abnormalClose(reason){
        this.closeWasClean = false;
        console.log("#DBG3", `Modify clean to: ${this.closeWasClean}`)
        this.socket.close(1000, reason);
    }

    public disconnect() : void {
        this.closeWasClean = true;
        console.log("#DBG7", `Modify clean to: ${this.closeWasClean}`)
        this.isActive = false;
        console.log("#DBG7", `False to active: ${this.isActive}`)
        clearInterval(this.heartbeatTimer);
        this.reconnectTimer.reset();
        this.socket.close(1000, "Client disconnect");
    }

    private makeRef() : string {
        const newRef = this.ref + 1
        if(newRef === this.ref){ this.ref = 0 } else { this.ref = newRef }
        return this.ref.toString()
    }

    private handleMessage(message: ChannelMessage) {
        this.bindings
            .filter(handler => this.matchHandlerExpr(handler.eventName, message.event))
            .forEach(handler => handler.callBack(message))
    }

    private matchHandlerExpr(eventExpr: string, actualEventName: string): boolean {
        if (eventExpr === actualEventName) return true;
        var regexString = '^' + eventExpr.replace(/\*/g, '([^.]+)').replace(/#/g, '([^.]+\.?)+') + '$';
        return actualEventName.search(regexString) !== -1;
    }

    private ackMessage(message: ChannelMessage){
        if (this.socket.readyState != SocketState.CLOSING && this.socket.readyState != SocketState.CLOSED)
            this.socket.send(`Ack::${message.message_id}`);
    }

    private onSocketClose(event) {
        console.log("transport", `Async channel close: ${event.code}`);
        clearInterval(this.heartbeatTimer)
        if(!this.closeWasClean && event.code != 4403){
            console.log("#DBG", `Scheduling reconnect, clean: ${this.closeWasClean}`)
            this.reconnectTimer.schedule()
        }else{
            this.stateCallbacks.close.forEach(callback => callback(event));
        }

    }

    private resetHeartbeat() : void {
        this.pendingHeartbeatRef = null
        clearInterval(this.heartbeatTimer)
        this.heartbeatTimer = setInterval(() => this.sendHeartbeat(), this.heartbeatIntervalMs)
    }

    //Testing Only
    public rawSocket() : WebSocket {
        return this.socket;
    }

    public getDecoder() : MessageDecoder {
        return this.serializer;
    }

    private socketUrl() : string {
        return `${this.config.socket_url}?channel=${this.config.channel_ref}`;
    }

    private teardown(callback?: Function): void {
        if(this.tearingDown) return;
        this.tearingDown = true;
        if(!this.socket) {
            this.tearingDown = false;
            return callback && callback();
        }

        if (this.socket && this.socket.readyState != SocketState.CLOSED && this.socket.readyState != SocketState.CLOSING){
            this.socket.close();
        }

        this.waitForSocketClosed(() => {
            if (this.socket) {
                if(this.socket.readyState != SocketState.CLOSED)
                    console.log("#DBG8", `Socket maybe open after wait close ${this.socket.readyState}`)
                this.socket.onclose = function(){} // noop
                this.socket = null
            }
            this.tearingDown = false;
            callback && callback()
        });

    }

    private waitForSocketClosed(callback? : Function, tries = 1) : void {
        if (tries === 5 || !this.socket || this.socket.readyState === SocketState.CLOSED) {
            callback();
            return
        }

        setTimeout(() => this.waitForSocketClosed(callback, tries + 1),150 * tries)
    }


}

enum SocketState {
    CONNECTING,
    OPEN,
    CLOSING,
    CLOSED
}

export interface AsyncConfig{
    socket_url: string;
    channel_ref:string;
    channel_secret: string;
    enable_binary_transport?: boolean;
    heartbeat_interval? : number;
}


