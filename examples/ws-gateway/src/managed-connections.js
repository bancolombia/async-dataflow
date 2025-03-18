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

function formatConnectionId(key) {
    return key.replace(/-/g, '').replace(/\//g, '').replace(/\+/g, '');
}

module.exports = {
    addClient,
    getClient,
    removeClient,
    formatConnectionId
};