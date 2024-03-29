# Client JS

[![NPM](https://nodei.co/npm/@bancolombia/chanjs-client.png?downloads=true&downloadRank=true&stars=true)](https://www.npmjs.com/package/@bancolombia/chanjs-client)

Javascript library for async data flow implementation for browsers.

- [Client JS](#client-js)
- [How to use](#how-to-use)
  - [Install](#install)
  - [Usage](#asyncClient-basic-usage-example)

## How to use

you need to have a running instances of [async-dataflow-channel-sender](https://github.com/bancolombia/async-dataflow/tree/master/channel-sender)

### Install

```npm
npm i @bancolombia/chanjs-client --save
```

### AsyncClient basic usage example

You can understand better the flow with this sequence diagram.

![imagen](https://user-images.githubusercontent.com/12372370/137554898-0d652b9c-2598-4e1b-b681-554e0a9f00e7.png)

```javascript
import { AsyncClient } from '@bancolombia/chanjs-client';

...
const client = new AsyncClient({
    socket_url: "wss://some.domain:8984/socket",
    channel_ref: "some_channel_ref",
    channel_secret: "secret_from_some_auth_service",
    heartbeat_interval: 200
});
...
```

### Configuration parameters

| **Parameters**          | Description                                                                                                                                   | Default Value |
| ----------------------- | --------------------------------------------------------------------------------------------------------------------------------------------- | ------------- |
| socket_url              | [async-dataflow-channel-sender](https://github.com/bancolombia/async-dataflow/tree/master/channel-sender) cluster url                         |               |
| channel_ref             | channel getted from rest service of [async-dataflow-channel-sender](https://github.com/bancolombia/async-dataflow/tree/master/channel-sender) |               |
| channel_secret          | token getted from rest service of [async-dataflow-channel-sender](https://github.com/bancolombia/async-dataflow/tree/master/channel-sender)   |               |
| heartbeat_interval      | time in milliseconds to verify socket connection **this parameter must be less than the socket_idle_timeout on the channel sender**           | 750           |
| enable_binary_transport | boolean parameter to indicate use binary protocol                                                                                             | false         |
| dedupCacheDisable | boolean flag to control dedup operations of messages by its `message_id`. If `true` no dedup operation will be performed. | false |
| dedupCacheMaxSize | max ammount of elements to cache in the dedup process. Only if `dedupCacheDisable` is false. | 500 |
| dedupCacheTtl | time to live of cached elements in the dedup operation (in minutes). Only if `dedupCacheDisable` is false. | 15 |

### Subscribing to events

```javascript
client.listenEvent("event.some-name", (message) =>
  someCallback(message.payload)
);
```

You can also use amqp-match style name expressions when susbscribing to events. Examples:

```javascript
client.listenEvent("event.#", (message) => someCallback(message.payload));
client.listenEvent("event.some.*", (message) => someCallback(message.payload));
```

Messages will be delivered **at least once**, as Channel-Sender implements delivery guarantee. If your application is sensible to the reception of eventually duplicated messages, you can make use of the simple dedup operation this client provides, by caching message_ids by certain time and only invokig your callback once, or by implementing your own dedup operation.
