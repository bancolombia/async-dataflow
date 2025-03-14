const clients = {};

function addClient(ws, connectionId) {
    clients[connectionId] = ws;
}

function getClient(connectionId) {
    return clients[connectionId];
}

function removeClient(connectionId) {
    delete clients[connectionId];
}

module.exports = {
    addClient,
    getClient,
    removeClient
};