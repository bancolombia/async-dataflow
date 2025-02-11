import * as chai from 'chai';

import { AsyncConfig } from "../../src";
import { Server, WebSocket } from 'mock-socket';

import { ChannelMessage } from "../../src/channel-message";
import { JsonDecoder, BinaryDecoder } from "../../src/decoder";
import { Protocol, WsTransport } from "../../src/transport";
import "fast-text-encoding"
import { managedObservable, ManagedPromise, promiseFromObservable, timeout, waitFor } from '../utils/types.utils';

const assert: Chai.AssertStatic = chai.assert;
const TIMEOUT = 10000;


describe('WsTransport Tests', function () {
    let mockServer;
    let managed: ManagedPromise;
    let client: WsTransport;
    let config: AsyncConfig = {
        socket_url: "wss://host.local",
        channel_ref: "ab771f3434aaghjgr",
        channel_secret: "secret234342432dsfghjikujyg1221",
    };

    beforeEach(() => {
        managed = managedObservable();
        mockServer = new Server(`${config.socket_url}/ext/socket`);
        client = WsTransport.create(config, managed.onMessage, managed.onError, WebSocket);
    })

    afterEach((done) => {
        mockServer.stop(() => done());
    });

    after(() => {
        client.disconnect();
    });

    it('Should get name', () => {
        assert.equal(client.name(), 'ws');
    });

    it('Should try to connect with correct url', () => {
        client.connect();
        assert.equal(client.rawSocket().url, `${config.socket_url}/ext/socket?channel=ab771f3434aaghjgr`);
        client.disconnect();
    });

    it('Should notify socket connect', async () => {
        client.connect();
        const isOpen = await new Promise<boolean>(resolve => client.doOnSocketOpen((_event) => resolve(client.isOpen)));
        assert.isTrue(isOpen);
        client.disconnect();
    });

    it('Should authenticate with server and route message', async () => {
        mockServer.on('connection', socket => {
            socket.on('message', data => {
                if (data == `Auth::${config.channel_secret}`) {
                    console.log('server. auth ok');
                    socket.send('["", "", "AuthOk", ""]');
                    socket.send('["12", "", "person.registered", "CC111222"]');
                }
            });
        });

        assert.isFalse(client.isActive);
        client.connect();

        const message = await Promise.race([timeout(200), promiseFromObservable(managed.observableMsg)]);
        // @ts-ignore
        assert.isTrue(client.isActive);
        assert.deepEqual(message, new ChannelMessage("12", "person.registered", "", "CC111222"));
        client.disconnect();
    });


    it('Should send ack on message', async () => {
        mockServer.on('connection', socket => {
            socket.on('message', data => {
                if (data == `Auth::${config.channel_secret}`) {
                    console.log('server. auth ok');
                    socket.send('["", "", "AuthOk", ""]');
                    socket.send('["12", "", "person.registered", "CC111222"]');
                } else if (data == 'Ack::12') {
                    socket.send('["14", "", "ack.reply.ok", "ok"]');
                }
            });
        });

        client.connect();

        const result = await Promise.race([timeout(500), promiseFromObservable(managed.observableMsg, 2)]);
        // @ts-ignore
        assert.deepEqual(result, new ChannelMessage("14", "ack.reply.ok", "", "ok"));
        client.disconnect();
    });

});

describe('WsTransport url tests', function () {
    let managed: ManagedPromise;

    beforeEach(() => {
        managed = managedObservable();
    })

    afterEach((done) => done());

    it('Should try to connect with correct url', () => {
        let config: AsyncConfig = {
            socket_url: "http://host.local",
            channel_ref: "ab771f3434aaghjgr",
            channel_secret: "secret234342432dsfghjikujyg1221",
        };
        const client = WsTransport.create(config, managed.onMessage, managed.onError, WebSocket);

        client.connect();
        assert.equal(client.rawSocket().url, `ws://host.local/ext/socket?channel=ab771f3434aaghjgr`);
        client.disconnect();
    });

    it('Should try to connect with correct url with ssl', () => {
        let config: AsyncConfig = {
            socket_url: "https://host.local",
            channel_ref: "ab771f3434aaghjgr",
            channel_secret: "secret234342432dsfghjikujyg1221",
        };
        const client = WsTransport.create(config, managed.onMessage, managed.onError, WebSocket);

        client.connect();
        assert.equal(client.rawSocket().url, `wss://host.local/ext/socket?channel=ab771f3434aaghjgr`);
        client.disconnect();
    });
});

describe('Async Reconnection Tests', () => {

    it('Should ReConnect when server closes the socket', async () => {
        let config = {
            socket_url: "wss://reconnect.local:8984",
            channel_ref: "ab771f3434aaghjgr",
            channel_secret: "secret234342432dsfghjikujyg1221",
            heartbeat_interval: 200
        };
        let mockServer = new Server(`${config.socket_url}/ext/socket`);
        let managed = managedObservable();
        let client: WsTransport = WsTransport.create(config, managed.onMessage, managed.onError, WebSocket);

        let firstSocket;
        mockServer.on('connection', socket => {
            socket.on('message', data => {
                if (data == `Auth::${config.channel_secret}`) {
                    if (firstSocket == undefined) {
                        firstSocket = socket;
                        console.log('server. first auth ok');
                        socket.send('["", "", "AuthOk", ""]');
                        socket.send('["12", "", "person.registered", "CC111222"]');
                    } else {
                        console.log('server. second auth ok');
                        socket.send('["", "", "AuthOk", ""]');
                        // @ts-ignore
                        setTimeout(() => socket.send('["120", "", "person.registered2", "CC1112223"]'), 200)
                    }
                }
            });
        });

        client.connect();
        const message1 = await promiseFromObservable(managed.observableMsg);
        assert.deepEqual(message1, new ChannelMessage("12", "person.registered", "", "CC111222"));
        firstSocket.close({ code: 1006, reason: "Server closed", wasClean: false });

        // Should receive message after reconnection
        const message2 = await promiseFromObservable(managed.observableMsg, 2);
        assert.deepEqual(message2, new ChannelMessage("120", "person.registered2", "", "CC1112223"));


        client.disconnect();
        mockServer.close();
        mockServer.stop();
    }).timeout(TIMEOUT);


    it('Should ReConnect when no heartbeat', async () => {
        let config = {
            socket_url: "wss://reconnect.local:8985",
            channel_ref: "ab771f3434aaghjgr",
            channel_secret: "secret234342432dsfghjikujyg1221",
            heartbeat_interval: 200
        };
        let mockServer = new Server(`${config.socket_url}/ext/socket`);
        let managed = managedObservable();
        let client: WsTransport = WsTransport.create(config, managed.onMessage, managed.onError, WebSocket);
        let respondBeat = false;
        let connectCount = 0;

        mockServer.on('connection', socket => {
            socket.on('message', raw_data => {
                if (typeof raw_data == "string") {
                    let data = String(raw_data);
                    if (data == `Auth::${config.channel_secret}`) {
                        console.log('server. auth ok');
                        connectCount = connectCount + 1;
                        socket.send('["", "", "AuthOk", ""]');
                        // @ts-ignore
                        setTimeout(() => socket.send('["12", "", "person.registered", "CC111222"]'), 200)
                    } else if (data.startsWith("hb::") && respondBeat) {
                        let correlation = data.split("::")[1];
                        socket.send(`["", ${correlation}, ":hb", ""]`);
                    }
                }
            });
        });

        client.connect();

        const message = await promiseFromObservable(managed.observableMsg);
        assert.deepEqual(message, new ChannelMessage("12", "person.registered", "", "CC111222"));

        await timeout(600);
        respondBeat = true;
        const lastCount = connectCount;
        // @ts-ignore
        console.log("Count", connectCount);

        await timeout(700);
        client.disconnect();

        await new Promise((resolve, reject) => {
            mockServer.stop(() => {
                resolve(0);
            })
        });
        assert.approximately(connectCount, lastCount, 1);

    });

});

describe('Refresh token Tests', () => {

    let config = {
        socket_url: "wss://reconnect.local:8986",
        channel_ref: "ab771f3434aaghjgr",
        channel_secret: "secret234342432dsfghjikujyg1221",
        heartbeat_interval: 2000
    };

    it('Should ReConnect with new token', async () => {
        let mockServer = new Server(`${config.socket_url}/ext/socket`);
        let managed = managedObservable();
        let client: WsTransport = WsTransport.create(config, managed.onMessage, managed.onError, WebSocket);
        const secondToken = "new_token_secret12243";

        let firstSocket;
        mockServer.on('connection', socket => {
            socket.on('message', data => {
                if (firstSocket == undefined) {
                    firstSocket = socket;
                    if (data == `Auth::${config.channel_secret}`) {
                        console.log('server. first auth ok');
                        socket.send('["", "", "AuthOk", ""]');
                        socket.send(`["01", "", ":n_token", "${secondToken}"]`);
                        socket.send('["02", "", "person.registered", "CC10202029"]');
                    }
                } else {
                    if (data == `Auth::${config.channel_secret}`) {
                        console.log('server. second auth ok');
                        socket.send('["", "", "AuthOk", ""]');
                        socket.send('["12", "", "person.registered2", "CC1112223"]');
                    } else if (new String(data).startsWith('Auth::')) {
                        // @ts-ignore
                        console.log("server. invalid credentials");
                        mockServer.close({ code: 4403, reason: "Invalid auth", wasClean: true })
                    }
                }
            });
        });

        client.connect();

        const message1 = await promiseFromObservable(managed.observableMsg, 2);
        assert.deepEqual(message1, new ChannelMessage("02", "person.registered", "", "CC10202029"));

        config.channel_secret = "new_token_secret12243";
        firstSocket.close({ code: 1006, reason: "Server closed", wasClean: false });

        const message2 = await promiseFromObservable(managed.observableMsg);
        assert.deepEqual(message2, new ChannelMessage("12", "person.registered2", "", "CC1112223"));

        client.disconnect();
        mockServer.close();
        mockServer.stop();
    });

});

describe('Protocol negotiation Tests', function () {
    let client: WsTransport;
    let mockServer: Server;
    let baseConf = {
        socket_url: "wss://protocol.local",
        channel_ref: "ab771f3434aaghjgr",
        channel_secret: "secret234342432dsfghjikujyg1221",
    };

    let initServer = (selectProtocol) => {
        mockServer = new Server(`${baseConf.socket_url}/ext/socket`, {
            selectProtocol
        })
    };

    let connectAndGetDecoderSelected = async (config) => {
        const managed = managedObservable();
        client = WsTransport.create(config, managed.onMessage, managed.onError, WebSocket);
        const connected = new Promise<boolean>(resolve => client.doOnSocketOpen(() => resolve(true)));
        client.connect();
        const result = await waitFor(connected);
        assert.equal(result, true);
        return client.getDecoder();
    }

    afterEach((done) => {
        client.disconnect()
        mockServer.stop(() => done());
    });

    it('Should use Json decoder when specified', async () => {
        let config = {
            ...baseConf,
            enable_binary_transport: false
        };
        initServer((protocols) => {
            assert.deepEqual(protocols, [Protocol.JSON])
            return protocols[0];
        });

        const decoder = await connectAndGetDecoderSelected(config);
        assert.instanceOf(decoder, JsonDecoder);
    });

    it('Should use binary protocol when available', async () => {
        let config = {
            ...baseConf,
            enable_binary_transport: true
        };
        initServer((protocols) => {
            assert.includeMembers(protocols, [Protocol.BINARY, Protocol.JSON])
            return Protocol.BINARY;
        });

        const decoder = await connectAndGetDecoderSelected(config);
        assert.instanceOf(decoder, BinaryDecoder);
    });

    it('Should fallback to json protocol when server select it', async () => {
        let config = {
            ...baseConf,
            enable_binary_transport: true
        };
        initServer((protocols) => {
            assert.includeMembers(protocols, [Protocol.BINARY, Protocol.JSON])
            return Protocol.JSON;
        });

        const decoder = await connectAndGetDecoderSelected(config);
        assert.instanceOf(decoder, JsonDecoder);
    });

    it('Should fallback to Json decoder when Binary decoder is not available', async () => {
        let config = {
            ...baseConf,
            enable_binary_transport: true
        };

        //@ts-ignore
        const decoder = global.TextDecoder;
        // @ts-ignore
        global.TextDecoder = undefined;

        initServer((protocols) => {
            assert.deepEqual(protocols, [Protocol.JSON])
            return protocols[0];
        });

        const decoderSelected = await connectAndGetDecoderSelected(config);
        assert.instanceOf(decoderSelected, JsonDecoder);

        // @ts-ignore
        global.TextDecoder = decoder;
    });
});
