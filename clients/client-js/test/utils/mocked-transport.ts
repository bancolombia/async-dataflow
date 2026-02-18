import { ChannelMessage } from "../../src/channel-message.js";
import { Transport, TransportError } from "../../src/transport/index.js";
import sinonPkg from "sinon";

const { spy } = sinonPkg;

export class MockedTransport implements Transport {
    public connect = spy();
    public disconnect = spy();
    public connected = spy();
    constructor(private readonly nameValue: string,
        private readonly handleMessage: (_message: ChannelMessage) => void,
        private readonly errorCallback: (_error: TransportError) => void) {
    }

    name(): string {
        return this.nameValue;
    }

    send(message: string): void {
        // Simulate sending a message
        console.log(`MockedTransport: Sending message: ${message}`);
    }

    simulateMessage(message: ChannelMessage) {
        this.handleMessage(message);
    }

    simulateError(error: TransportError) {
        this.errorCallback(error);
    }

}