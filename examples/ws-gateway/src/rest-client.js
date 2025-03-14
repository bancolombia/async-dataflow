const axios = require('axios');
const { Observable, retry, lastValueFrom } = require('rxjs');
const HOST = 'http://localhost:8081';
const RETRY_COUNT = 5;

function retriedPost(url, body, opts, retries = RETRY_COUNT) {
    return lastValueFrom(new Observable((observer) => {
        console.log(`POST ${url}`, body);
        axios
            .post(url, body, opts)
            .then((response) => {
                observer.next(response);
                observer.complete();
            })
            .catch((error) => {
                observer.error(error);
            });
    })
        .pipe(retry(retries)));
}

function notifyConnect(connectionId, headers) {
    headers['connectionid'] = connectionId;
    return axios.post(`${HOST}/ext/channel/gateway/connect`, null, { headers })
        .catch(err => {
            console.error(`Failed to notify connect -> status: ${err.status} body: ${err.data}`);
        });
}

function notifyDisconnect(connectionId) {
    const headers = { connectionid: connectionId };
    return axios.post(`${HOST}/ext/channel/gateway/disconnect`, null, { headers })
        .catch(err => {
            console.error(`Failed to notify disconnect -> status: ${err.status} body: ${err.data}`);
        });
}

function forwardMessage(connectionId, body) {
    console.log(body.toString());
    const headers = { connectionid: connectionId, 'Content-Type': 'application/json' };
    return retriedPost(`${HOST}/ext/channel/gateway/message`, body, { headers })
        .catch(err => {
            console.error(`Failed to forward message -> status: ${err.status} body: ${err.data}`);
        });
}

module.exports = {
    notifyConnect,
    notifyDisconnect,
    forwardMessage
};