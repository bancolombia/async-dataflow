import { ChannelMessage } from "../../src";
import { Transport, TransportError } from "../../src/transport";
import * as sinon from "sinon";

export class MockedTransport implements Transport {
    public connect = sinon.spy();
    public disconnect = sinon.spy();
    public connected = sinon.spy();
    constructor(private readonly nameValue: string,
        private readonly handleMessage: (_message: ChannelMessage) => void,
        private readonly errorCallback: (_error: TransportError) => void) {
    }

    name(): string {
        return this.nameValue;
    }

    simulateMessage(message: ChannelMessage) {
        this.handleMessage(message);
    }

    simulateError(error: TransportError) {
        this.errorCallback(error);
    }

}