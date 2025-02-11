import { Observable, Subscriber } from "rxjs";
import { ChannelMessage } from "../../src/channel-message";
import { TransportError } from "../../src/transport";
import * as sinon from "sinon";
import { AsyncClient } from "../../src";
import { MockedTransport } from "./mocked-transport";

export interface ManagedPromise {
    observableMsg: Observable<ChannelMessage>,
    onMessage: (message: ChannelMessage) => void,
    onError: (error: TransportError) => void
};

export function timeout(millis: number): Promise<any> {
    return new Promise(resolve => {
        // @ts-ignore
        setTimeout(resolve, millis, "timeout");
    });
}

export function promiseFromObservable(observable: Observable<ChannelMessage>, index: number = 1): Promise<ChannelMessage> {
    return new Promise<ChannelMessage>(resolve => {
        observable.subscribe({
            next: (message: ChannelMessage) => {
                console.log('message', message);
                if (index == 1) {
                    resolve(message);
                }
                index--;
            }
        });
    });
}

export function waitFor(promise) {
    return Promise.race([timeout(200), promise]);
}

export function managedObservable() {
    let observable: Subscriber<ChannelMessage>;
    const observableMsg = new Observable<ChannelMessage>(obs => {
        observable = obs;
    });
    const onMessage = (message: ChannelMessage) => observable.next(message);
    const onError = sinon.spy();
    return { observableMsg, onMessage, onError };
}

export function promisedMessage(client: AsyncClient,
    mockedTransport: MockedTransport,
    simulatedMessage: ChannelMessage,
    eventName: string): Promise<ChannelMessage> {
    return new Promise(resolve => {
        client.listenEvent(eventName, message => resolve(message));
        mockedTransport.simulateMessage(simulatedMessage);
    });
}