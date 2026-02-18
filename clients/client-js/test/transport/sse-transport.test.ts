import * as chai from 'chai';

import { AsyncConfig } from "../../src/async-config.js";
import { SSEMockServer } from "../utils/sse-mock-server.js";

import { ChannelMessage } from "../../src/channel-message.js";
import { SseTransport } from "../../src/transport/sse-transport.js";
import "fast-text-encoding"
import { managedObservable, promiseFromObservable } from '../utils/types.utils.js';

const assert: Chai.AssertStatic = chai.assert;

describe('SseTransport Tests', function () {
    let client: SseTransport;

    before(async () => {
        await SSEMockServer.start();
    });

    afterEach(() => {
        client.disconnect();
    });

    after((done) => {
        SSEMockServer.stop(() => done());
    });

    it('Should authenticate with server route message and call connected', async () => {
        // Arrange
        const config: AsyncConfig = {
            socket_url: "ws://localhost:3000",
            channel_ref: "channel-1",
            channel_secret: "token-1",
            maxReconnectAttempts: 1
        };
        SSEMockServer.mock({
            url: `/ext/sse?channel=${config.channel_ref}`,
            response: {
                token: config.channel_secret,
                messages: [
                    { message: '["12", "", "person.registered", "CC111222"]' }
                ]
            }
        });
        const managed = managedObservable();
        const resolveMessage = promiseFromObservable(managed.observableMsg);
        // Act
        client = SseTransport.create(config, managed.onMessage, managed.onError) as SseTransport;
        await new Promise((resolve) => {
            client.connect(() => resolve(true));
        });
        const message = await resolveMessage;
        // Assert
        assert.equal(client.name(), 'sse');
        assert.deepEqual(message, new ChannelMessage("12", "person.registered", "", "CC111222"));
    });

    it('Should retry connection and notify when max retries reached', async () => {
        // Arrange
        const config: AsyncConfig = {
            socket_url: "ws://localhost:3000",
            channel_ref: "channel-2",
            channel_secret: "token-2",
            maxReconnectAttempts: 3
        };
        SSEMockServer.mock({
            url: `/ext/sse?channel=${config.channel_ref}`,
            response: {
                status: 500,
                token: config.channel_secret,
                messages: [
                    { message: '["12", "", "person.registered", "CC111222"]' }
                ]
            }
        });
        const managed = managedObservable();
        // Create subscription
        promiseFromObservable(managed.observableMsg);
        // Act
        const response = await new Promise((resolve) => {
            client = SseTransport.create(config, managed.onMessage, (err) => {
                resolve(err);
            }) as SseTransport;
            client.connect();
        });
        // Override mock to simulate connection success
        SSEMockServer.mock({
            url: `/ext/sse?channel=${config.channel_ref}`,
            response: {
                token: config.channel_secret,
                messages: [
                    { message: '["12", "", "person.registered", "CC111222"]' }
                ]
            }
        });
        const connected = await new Promise((resolve) => {
            client.connect(() => resolve(true));
        });
        // Assert
        assert.isTrue(connected);
        assert.deepEqual(response, { code: 1, message: "Internal Server Error ", origin: "sse" });
    }).timeout(10000);

    it('Should connect with a new token', async () => {
        // Arrange
        const config: AsyncConfig = {
            socket_url: "ws://localhost:3000",
            channel_ref: "channel-3",
            channel_secret: "token-3",
            maxReconnectAttempts: 3
        };
        SSEMockServer.mock({
            url: `/ext/sse?channel=${config.channel_ref}`,
            response: {
                token: config.channel_secret,
                messages: [
                    { message: '["11", "", ":n_token", "newtoken"]' },
                    { message: '["12", "", "person.registered", "CC111222"]' }
                ]
            }
        });
        const managed = managedObservable();
        // Create subscription
        const messagePromise = promiseFromObservable(managed.observableMsg, 2);
        // Act
        client = SseTransport.create(config, managed.onMessage, managed.onError) as SseTransport;
        const connected = await new Promise((resolve) => {
            client.connect(() => resolve(true));
        });
        await messagePromise;
        client.disconnect();

        // Update token in mock server
        SSEMockServer.mock({
            url: `/ext/sse?channel=${config.channel_ref}`,
            response: {
                token: 'newtoken',
                messages: [
                    { message: '["12", "", "person.registered", "CC111223"]' }
                ]
            }
        });
        const firstMessagePromise = promiseFromObservable(managed.observableMsg, 1);
        // Connection should use the second token...
        const connectedTwoAttempt = await new Promise((resolve) => {
            client.connect(() => resolve(true));
        });
        const firstMessage = await firstMessagePromise;
        // Assert
        assert.isTrue(connected);
        assert.isTrue(connectedTwoAttempt);
        assert.deepEqual(firstMessage, new ChannelMessage("12", "person.registered", "", "CC111223"))
    });

});