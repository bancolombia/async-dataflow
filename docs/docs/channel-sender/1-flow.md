---
sidebar_position: 1
---

# Channel Flow

## 1. Register a channel

This is a flow to consume the rest endpoint to register a channel and obtain a tuple consisting of:

- channel reference id
- channel secret key

```mermaid
sequenceDiagram
    autonumber
    SPA / Mobile App->>ADF Channel Sender: Hello I wish to register a channel to receive async events.
    activate ADF Channel Sender
    ADF Channel Sender->>ADF Channel Sender: Generate a channel ref and secret
    ADF Channel Sender-->>SPA / Mobile App: sure, here you go... Your channel ref and secret sir!
    deactivate ADF Channel Sender
    activate SPA / Mobile App
    SPA / Mobile App->>SPA / Mobile App: Ok, now I'm ready to open this channel
    deactivate SPA / Mobile App
```

## 2. Open a connection to the channel

This is where actually a channel is opened by the client (SPA or Mobile App) to start receiving events.

```mermaid
sequenceDiagram
    autonumber
    activate SPA / Mobile App
    SPA / Mobile App->>ADF Channel Sender: websocket channel [data: channel_ref]
    activate ADF Channel Sender
    ADF Channel Sender-->>SPA / Mobile App: channel openned.
    SPA / Mobile App->>ADF Channel Sender: Send secret key to authenticate the channel
    ADF Channel Sender->>ADF Channel Sender: key validated
    deactivate ADF Channel Sender
    ADF Channel Sender-->>SPA / Mobile App: Channel is ready to receive messages.
    deactivate SPA / Mobile App
```

## 3. Send messages to Front End

This flow allows your backend services or applications to deliver messages to your front end app.

```mermaid
sequenceDiagram
    autonumber
    activate ADF Channel Sender
    Backend service->>ADF Channel Sender: POST /ext/channel/deliver_message<br>(body includes channel_reference)
    ADF Channel Sender-->>Backend service: Http Status 202 (request received).
    ADF Channel Sender->>ADF Channel Sender: Locate channel process<br>tied to channel ref id
    deactivate ADF Channel Sender
    activate ADF Channel Sender
    ADF Channel Sender->>+SPA / Mobile App: push message
    deactivate ADF Channel Sender
```

Flows (1) and (2) are supported by the ADF existent clients:

- [Javascript](https://github.com/bancolombia/async-dataflow/tree/master/clients/client-js)
- [Dart](https://github.com/bancolombia/async-dataflow/tree/master/clients/client-dart)

Flow (3) doesn't have a client implementation, but its fairly simple to implement in any language since given it's a 
rest endpoint that receives a pre-defined json content, which includes the channel reference id and the payload 
to be delivered to the front end. See the [API Documentation](#api-documentation) for more details.