# Client JS

Javascript library for async data flow implementation for browsers.

- [Client JS](#client-js)
- [How to use](#how-to-use)
  - [Install](#install)
  - [Usage](#asyncClient-basic-usage-example)

## How to use

you need to have a running instances of [async-dataflow-channel-sender](https://github.com/bancolombia/async-dataflow/channel-sender)

### Install

```npm
npm install chanjs-client --save
```

### AsyncClient basic usage example

You can understand better the flow with this sequence diagram.

<img src="https://raw.githubusercontent.com/bancolombia/async-dataflow-channel-client-js/master/doc/sequence-diagram-async-data-flow.png" width="600">

```javascript
import { AsyncClient } from 'chanjs-client';

...
const client = new AsyncClient({
    socket_url: "wss://some.domain:8984/socket",
    channel_ref: "some_channel_ref",
    channel_secret: "secret_from_some_auth_service",
    heartbeat_interval: 200
});
...
```

| **Parameters**          | Description                                                                                                                         | Default Value |
| ----------------------- | ----------------------------------------------------------------------------------------------------------------------------------- | ------------- |
| socket_url              | [async-dataflow-channel-sender](https://github.com/bancolombia/async-dataflow/channel-sender) cluster url                           |               |
| channel_ref             | channel getted from rest service of [async-dataflow-channel-sender](https://github.com/bancolombia/async-dataflow/channel-sender)   |               |
| channel_secret          | token getted from rest service of [async-dataflow-channel-sender](https://github.com/bancolombia/async-dataflow/channel-sender)     |               |
| heartbeat_interval      | time in milliseconds to verify socket connection **this parameter must be less than the socket_idle_timeout on the channel sender** | 750           |
| enable_binary_transport | boolean parameter to indicate use binary protocol                                                                                   | false         |

```javascript
client.listenEvent("event.some-name", (message) =>
  someCallback(message.payload)
);
```
