const WebSocket = require('ws');
const http = require('http');
const { URL } = require('url');
const conections = require('./managed-connections.js');
const client = require('./rest-client.js');

const server = http.createServer((req, res) => {
    console.log(req.headers);
    res.writeHead(200, { 'Content-Type': 'text/plain' });
    res.end('WebSocket server running');
});
const wss = new WebSocket.Server({ noServer: true });

function mapQueryParameters(url) {
    const fullUrl = new URL(url, 'http://localhost');
    const params = {};
    fullUrl.searchParams.forEach((value, name) => {
        params[name] = value;
    });
    return params;
}

server.on('upgrade', (req, socket, head) => {
    console.log('upgrade request');
    const params = mapQueryParameters(req.url);
    const connectionId = req.headers['sec-websocket-key'].replace(/-/g, '').replace(/\//g, '');
    console.log(`New WebSocket connection ${connectionId}`);
    client.notifyConnect(connectionId, params || {})
        .then(res => {
            if (res) {
                console.log('Connection started with response:', res.data);
            }

            wss.handleUpgrade(req, socket, head, (ws) => {
                req.headers['sec-websocket-key'] = connectionId;
                wss.emit('connection', ws, req);
            });
        })
        .catch(err => {
            socket.destroy();
            console.error('Failed to notify connect:', err);
        });

});

wss.on('connection', (ws, req) => {
    const connectionId = req.headers['sec-websocket-key'];
    conections.addClient(ws, connectionId);
    ws.on('message', (message) => {
        console.log('Received for:', connectionId);
        client.forwardMessage(connectionId, message)
            .then(res => {
                if (res && res.data) {
                    ws.send(JSON.stringify(res.data));
                    console.log('Message forwarded with response:', res.data);
                }
            })
            .catch(err => {
                console.error('Failed to forward message:', err);
            });
    });

    ws.on('close', () => {
        console.log('WebSocket connection closed:', connectionId);
        conections.removeClient(connectionId);
        client.notifyDisconnect(connectionId)
            .then(res => {
                if (res) {
                    console.log('Connection closed with response:', res.data);
                }
            })
            .catch(err => {
                console.error('Failed to notify disconnect:', err);
            });
    });
});

server.listen(8083, () => {
    console.log('Web Socket Server is listening on ws://localhost:8083');
});