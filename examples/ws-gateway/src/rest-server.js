const express = require('express');
const http = require('http');
const connections = require('./managed-connections.js');

const app = express();
app.use(express.json());
const restApiServer = http.createServer(app);

app.post('/@connections/:connectionId', async (req, res) => {
    const ws = connections.getClient(req.params.connectionId);
    if (ws) {
        console.log(`forwarding message to ${req.params.connectionId}`);
        ws.send(JSON.stringify(req.body));
        res.sendStatus(204);
    } else {
        console.log(`connection ${req.params.connectionId} not found`);
        res.sendStatus(404);
    }
});
app.delete('/@connections/:connectionId', async (req, res) => {
    const ws = connections.getClient(req.params.connectionId);
    if (ws) {
        console.log(`closing connection ${req.params.connectionId}`);
        ws.close();
        res.sendStatus(204);
    } else {
        console.log(`connection ${req.params.connectionId} not found`);
        res.sendStatus(404);
    }
});

app.get('/@connections/:connectionId', async (req, res) => {
    const ws = connections.getClient(req.params.connectionId);
    if (ws) {
        console.log(`connection info ${req.params.connectionId} found`);
        res.send({ status: 'open' });
    } else {
        console.log(`connection ${req.params.connectionId} not found`);
        res.sendStatus(404);
    }
});


restApiServer.listen(3000, () => {
    console.log('REST API Server listening on http://localhost:3000');
});