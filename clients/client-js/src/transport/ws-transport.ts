import { JsonDecoder } from "../json-decoder";
import { MessageDecoder } from "../serializer"
import { ChannelMessage } from "../channel-message";
import { RetryTimer } from "../retry-timer";
import { BinaryDecoder } from "../binary-decoder";
import { Protocol } from "../protocol";
import { Utils } from "../utils";
import { AsyncConfig } from "../async-config";
import { Transport } from "./transport";
import { TransportError } from "./transport-error";
import { SocketState } from "./socket-state";

export class WsTransport implements Transport {
    private actualToken;
    private socket: WebSocket;
    public isOpen: boolean = false;
    public isActive: boolean = false;
    private stateCallbacks = { open: [], close: [], error: [], message: [] }
    private ref = 0;
    private pendingHeartbeatRef: string = null;
    private closeWasClean: boolean = false;
    private heartbeatTimer = null;
    private readonly heartbeatIntervalMs: number;
    private tearingDown: boolean = false;
    private reconnectTimer: RetryTimer;
    private serializer: MessageDecoder;
    private subProtocols: string[] = [Protocol.JSON]

    private readonly HEARTBEAT_TIMEOUT = 3051;

    constructor(private config: AsyncConfig,
        private handleMessage = (_message: ChannelMessage) => { },
        private errorCallback = (_error: TransportError) => { },
        private readonly transport: any = null) {

        const intWindow = typeof window !== "undefined" ? window : null;
        this.transport = transport || intWindow['WebSocket'];
        this.heartbeatIntervalMs = config.heartbeat_interval || 750;
        this.reconnectTimer = new RetryTimer(() => this.teardown(() => this.connect()),
            50,
            (num) => Utils.jitter(num, 0.25),
            //config.maxReconnectAttempts,
            2,
            () => this.errorCallback({ code: 1, message: "Max retries reached" })
        );
        this.actualToken = config.channel_secret;
        if (config.enable_binary_transport && typeof TextDecoder !== "undefined") {
            this.subProtocols.push(Protocol.BINARY)
        }
    }

    public connect() {
        if (this.socket && this.socket.readyState == SocketState.OPEN) { // TODO: Verify conditions
            console.debug('async-client. socket already created and open');
            return;
        }
        console.debug('async-client. connect() called')
        this.socket = new this.transport(this.socketUrl(), this.subProtocols);
        this.socket.binaryType = "arraybuffer";
        this.socket.onopen = (event) => this.onSocketOpen(event)
        this.socket.onerror = error => this.onSocketError(error)
        this.socket.onmessage = event => this.onSocketMessage(event)
        this.socket.onclose = event => this.onSocketClose(event)
        console.log(`async-client. Subprotocols: ${this.subProtocols}`);
    }

    public disconnect(): void {
        console.info('async-client. disconnect() called')
        this.closeWasClean = true;
        this.isActive = false;
        clearInterval(this.heartbeatTimer);
        this.reconnectTimer.reset();
        this.socket.close(1000, "Client disconnect");
        console.info('async-client. disconnect() called end')
    }

    // internal functions

    public doOnSocketOpen(callback) {
        this.stateCallbacks.open.push(callback)
    }

    private onSocketOpen(event) {
        this.selectSerializerForProtocol();
        this.isOpen = true;
        this.resetHeartbeat();
        this.socket.send(`Auth::${this.actualToken}`)
        this.stateCallbacks.open.forEach((callback) => callback(event));
    }

    private selectSerializerForProtocol(): void {
        if (this.socket.protocol == Protocol.BINARY) {
            this.serializer = new BinaryDecoder();
        } else {
            this.serializer = new JsonDecoder();
        }
    }

    private onSocketError(event) {
        console.log('error', event)
    }

    private onSocketMessage(event) {
        const message = this.serializer.decode(event)
        if (!this.isActive && message.event == "AuthOk") {
            this.isActive = true;
            this.reconnectTimer.reset();
            console.log('async-client. Auth OK');
        } else if (message.event == ":hb" && message.correlation_id == this.pendingHeartbeatRef) {
            this.pendingHeartbeatRef = null;
        } else if (message.event == ":n_token") {
            this.actualToken = message.payload;
            this.ackMessage(message);
            this.handleMessage(message);
        } else if (this.isActive) {
            this.ackMessage(message);
            this.handleMessage(message);
        } else {
            const txt = "Unexpected message before AuthOK";
            console.error(txt, message);
        }
    }

    private sendHeartbeat() {
        if (!this.isActive) { return }
        if (this.pendingHeartbeatRef) {
            this.pendingHeartbeatRef = null
            const reason = "heartbeat timeout. Attempting to re-establish connection";
            console.info(`async-client. ${reason}`)
            this.abnormalClose(reason)
            return;
        }
        this.pendingHeartbeatRef = this.makeRef();
        this.socket.send(`hb::${this.pendingHeartbeatRef}`);
    }

    private abnormalClose(reason) {
        this.closeWasClean = false;
        console.warn(`async-client. Abnormal close: ${reason}`)
        this.socket.close(this.HEARTBEAT_TIMEOUT, reason);
    }

    private makeRef(): string {
        const newRef = this.ref + 1
        if (newRef === this.ref) { this.ref = 0 } else { this.ref = newRef }
        return this.ref.toString()
    }

    private ackMessage(message: ChannelMessage) {
        if (this.socket.readyState != SocketState.CLOSING && this.socket.readyState != SocketState.CLOSED) {
            this.socket.send(`Ack::${message.message_id}`);
        }
    }

    private onSocketClose(event) {
        this.isActive = false;
        console.warn(`async-client. channel close: ${event.code} ${event.reason}`);
        clearInterval(this.heartbeatTimer)
        const reason = Utils.extractReason(event.reason);
        const shouldRetry = event.code > 1001 || (event.code == 1001 && reason >= 3050);

        if (!this.closeWasClean && shouldRetry && event.reason != 'Invalid token for channel') {
            console.log(`async-client. Scheduling reconnect, clean: ${this.closeWasClean}`)
            this.reconnectTimer.schedule()
        } else {
            this.stateCallbacks.close.forEach(callback => callback(event));
        }

    }

    private resetHeartbeat(): void {
        this.pendingHeartbeatRef = null
        clearInterval(this.heartbeatTimer)
        this.heartbeatTimer = setInterval(() => this.sendHeartbeat(), this.heartbeatIntervalMs)
    }

    //Testing Only
    public rawSocket(): WebSocket {
        return this.socket;
    }

    public getDecoder(): MessageDecoder {
        return this.serializer;
    }

    private socketUrl(): string {
        let url = this.config.socket_url;
        if (url.startsWith('http')) {
            url = url.replace('http', 'ws');
        }
        return `${url}/ext/socket?channel=${this.config.channel_ref}`;
    }

    private teardown(callback?: () => void): void {
        if (this.tearingDown) return;
        this.tearingDown = true;
        if (!this.socket) {
            this.tearingDown = false;
            return callback && callback();
        }

        if (this.socket && this.socket.readyState != SocketState.CLOSED && this.socket.readyState != SocketState.CLOSING) {
            this.socket.close();
        }

        this.waitForSocketClosed(() => {
            if (this.socket) {
                this.socket.onclose = function () { } // noop
                this.socket = null
            }
            this.tearingDown = false;
            callback && callback()
        });

    }

    private waitForSocketClosed(callback?: () => void, tries = 1): void {
        if (tries === 5 || !this.socket || this.socket.readyState === SocketState.CLOSED) {
            callback();
            return
        }

        setTimeout(() => this.waitForSocketClosed(callback, tries + 1), 150 * tries)
    }


}
