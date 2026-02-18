import * as chai from 'chai';
import sinonPkg from "sinon";
import { AsyncClient } from "../src/async-client.js";
import { AsyncConfig } from "../src/async-config.js";
import { Cache } from "../src/cache.js";
import { SseTransport, WsTransport } from "../src/transport/index.js";
import { MockedTransport } from './utils/mocked-transport.js';
import { ChannelMessage } from '../src/channel-message.js';
import { promisedMessage, timeout } from './utils/types.utils.js';

const { spy } = sinonPkg;
const { stub } = sinonPkg;

const assert: Chai.AssertStatic = chai.assert;

describe('AsyncClient Constructor Tests', function () {
    let config: AsyncConfig;
    let mockTransport: any;

    beforeEach(() => {
        config = {
            socket_url: "wss://host.local",
            channel_ref: "ab771f3434aaghjgr",
            channel_secret: "secret234342432dsfghjikujyg1221",
            dedupCacheDisable: false,
            dedupCacheMaxSize: 100,
            dedupCacheTtl: 60,
            maxReconnectAttempts: 3,
            checkConnectionOnFocus: true
        };
        mockTransport = stub();
    });

    it('should initialize with default transports if none provided', function () {
        const client = new AsyncClient(config, null, mockTransport);
        assert.deepEqual(client['transports'], ['ws', 'sse']);
    });

    it('should initialize with provided transports', function () {
        const client = new AsyncClient(config, ['ws'], mockTransport);
        assert.deepEqual(client['transports'], ['ws']);
    });

    it('should initialize cache if dedupCacheDisable is false', function () {
        const client = new AsyncClient(config, ['ws'], mockTransport);
        assert.instanceOf(client['cache'], Cache);
    });

    it('should not initialize cache if dedupCacheDisable is true', function () {
        config.dedupCacheDisable = true;
        const client = new AsyncClient(config, ['ws'], mockTransport);
        assert.isUndefined(client['cache']);
    });

    it('should set up focus event listener if checkConnectionOnFocus is true', function () {
        const addEventListenerSpy = spy(window, 'addEventListener');
        new AsyncClient(config, ['ws'], mockTransport);
        assert.isTrue(addEventListenerSpy.called);
        addEventListenerSpy.restore();
    });

    it('should not set up focus event listener if checkConnectionOnFocus is false', function () {
        config.checkConnectionOnFocus = false;
        const addEventListenerSpy = spy(window, 'addEventListener');
        new AsyncClient(config, ['ws'], mockTransport);
        assert.isFalse(addEventListenerSpy.called);
        addEventListenerSpy.restore();
    });

    it('should instantiate the correct transport', function () {
        const wsTransportStub = stub(WsTransport, 'create');
        const sseTransportStub = stub(SseTransport, 'create');

        new AsyncClient(config, ['ws'], mockTransport);
        assert.isTrue(wsTransportStub.calledOnce);
        assert.isFalse(sseTransportStub.called);

        new AsyncClient(config, ['sse'], mockTransport);
        assert.isTrue(sseTransportStub.calledOnce);

        wsTransportStub.restore();
        sseTransportStub.restore();
    });

    it('should instantiate the transport', function () {
        const instantiationStub = stub(SseTransport, 'create');
        instantiationStub.callsFake((_config, messageHandler, errorHandler) => {
            return new MockedTransport('sse', messageHandler!, errorHandler!)
        });
        new AsyncClient(config, ['sse']);

        assert.isTrue(instantiationStub.calledOnce);

        instantiationStub.restore();
    });
});

describe('Event handler matching Tests', function () {
    let instantiationStub: sinon.SinonStub;
    let mockedTransport: MockedTransport;
    let client: AsyncClient;
    const config = {
        socket_url: "wss://host.local/socket",
        channel_ref: "ab771f3434aaghjgr",
        channel_secret: "secret234342432dsfghjikujyg1221",
    };

    beforeEach(() => {
        instantiationStub = stub(WsTransport, 'create');
        instantiationStub.callsFake((_config, messageHandler, errorHandler) => {
            return new MockedTransport('ws', messageHandler!, errorHandler!)
        });
        client = new AsyncClient(config, ['ws']);
        mockedTransport = client['currentTransport'] as any;
        client.connect();
    })

    afterEach(() => {
        instantiationStub.restore();
    });

    after(() => {
        client.disconnect();
    });

    it('Should match direct equality', async () => {
        const data = "Hi, There";
        const simulatedMessage = new ChannelMessage("1", "quick.orange.rabbit", "1", data);
        const message = promisedMessage(client, mockedTransport, simulatedMessage, "quick.orange.rabbit");

        const result = await Promise.race([timeout(200), message]);
        assert.equal(result.payload, data);
    });

    it('Should match single word wildcard I', async () => {
        const data = "Hi, There Rabbit";
        const simulatedMessage = new ChannelMessage("1", "quick.orange.rabbit", "1", data);
        const message = promisedMessage(client, mockedTransport, simulatedMessage, "quick.orange.*");

        const result = await Promise.race([timeout(200), message]);
        assert.equal(result.payload, data);
    });

    it('Should match single word wildcard II', async () => {
        const data = "Hi, There Fox";
        const simulatedMessage = new ChannelMessage("1", "lazy.brown.fox", "1", data);
        const message = promisedMessage(client, mockedTransport, simulatedMessage, "lazy.*.fox");

        const result = await Promise.race([timeout(200), message]);
        assert.equal(result.payload, data);
    });

    it('Should match single word wildcard III', async () => {
        const data = "Hi, There Elephant";
        const simulatedMessage = new ChannelMessage("1", "lazy.orange.elephant", "1", data);
        const message = promisedMessage(client, mockedTransport, simulatedMessage, "*.orange.elephant");

        const result = await Promise.race([timeout(200), message]);
        assert.equal(result.payload, data);
    });

    it('Should match multi word wildcard', async () => {
        const data = "Hi, There Male Bird";
        const simulatedMessage = new ChannelMessage("1", "quick.white.male.bird", "1", data);
        const simulatedMessage2 = new ChannelMessage("2", "quick.orange.rabbit", "2", "Hi, There Rabbit");
        const message = promisedMessage(client, mockedTransport, simulatedMessage, "quick.#.bird");
        const message2 = promisedMessage(client, mockedTransport, simulatedMessage2, "lazy.#.rabbit");

        const result = await Promise.race([timeout(200), message]);
        const result2 = await Promise.race([timeout(200), message2]);
        assert.equal(result.payload, data);
        assert.equal(result2, 'timeout');
    });

});

describe('Dedup messages Tests', function () {
    let instantiationStub: sinon.SinonStub;
    let mockedTransport: MockedTransport;
    let client: AsyncClient;
    const config: AsyncConfig = {
        socket_url: "wss://host.local/socket",
        channel_ref: "ab771f3434aaghjgr",
        channel_secret: "secret234342432dsfghjikujyg1221",
    };

    beforeEach(() => {
        instantiationStub = stub(WsTransport, 'create');
        instantiationStub.callsFake((_config, messageHandler, errorHandler) => {
            return new MockedTransport('ws', messageHandler!, errorHandler!)
        });
    })

    afterEach(() => {
        instantiationStub.restore();
    });

    after(() => {
        client.disconnect();
    });

    it('Should dedup repeated message', async () => {
        client = new AsyncClient(config, ['ws']);
        mockedTransport = client['currentTransport'] as any;
        client.connect();

        const simulatedMessage = new ChannelMessage("1", "quick.orange.rabbit", "1", "Hi, There");
        const onMessage = spy();
        // Act
        client.listenEvent("quick.orange.rabbit", onMessage);
        mockedTransport.simulateMessage(simulatedMessage);
        mockedTransport.simulateMessage(simulatedMessage);
        // Assert
        assert.equal(onMessage.callCount, 1);
    });

    it('Should not dedup different messageid', async () => {
        client = new AsyncClient(config, ['ws']);
        mockedTransport = client['currentTransport'] as any;
        client.connect();

        const simulatedMessage = new ChannelMessage("1", "quick.orange.rabbit", "1", "Hi, There");
        const simulatedMessage2 = new ChannelMessage("2", "quick.orange.rabbit", "2", "Hi, There");
        const onMessage = spy();
        // Act
        client.listenEvent("quick.orange.rabbit", onMessage);
        mockedTransport.simulateMessage(simulatedMessage);
        mockedTransport.simulateMessage(simulatedMessage2);
        // Assert
        assert.equal(onMessage.callCount, 2);
    });

    it('Should not dedup same messageid when cache disabled', async () => {
        config.dedupCacheDisable = true;
        client = new AsyncClient(config, ['ws']);
        mockedTransport = client['currentTransport'] as any;
        client.connect();

        const simulatedMessage = new ChannelMessage("1", "quick.orange.rabbit", "1", "Hi, There");
        const onMessage = spy();
        // Act
        client.listenEvent("quick.orange.rabbit", onMessage);
        mockedTransport.simulateMessage(simulatedMessage);
        mockedTransport.simulateMessage(simulatedMessage);
        mockedTransport.simulateMessage(simulatedMessage);
        // Assert
        assert.equal(onMessage.callCount, 3);
    });

});

describe('Renew token Tests', function () {
    let instantiationStub: sinon.SinonStub;
    let mockedTransport: MockedTransport;
    let client: AsyncClient;
    const config: AsyncConfig = {
        socket_url: "wss://host.local/socket",
        channel_ref: "ab771f3434aaghjgr",
        channel_secret: "secret234342432dsfghjikujyg1221",
    };

    beforeEach(() => {
        instantiationStub = stub(WsTransport, 'create');
        instantiationStub.callsFake((_config, messageHandler, errorHandler) => {
            return new MockedTransport('ws', messageHandler!, errorHandler!)
        });
    })

    afterEach(() => {
        instantiationStub.restore();
    });

    after(() => {
        client.disconnect();
    });

    it('Should update token', async () => {
        client = new AsyncClient(config, ['ws']);
        mockedTransport = client['currentTransport'] as any;
        client.connect();

        const simulatedMessage = new ChannelMessage("1", ":n_token", "1", "token");
        // Act
        mockedTransport.simulateMessage(simulatedMessage);
        // Assert
        assert.equal(client['config'].channel_secret, "token");
    });

});