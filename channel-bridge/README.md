# Channel Bridge

Distributed Elixir Cluster implementation of a async messages router.

- [How it works](#how-it-works)
- [Install](#install)
- [Configuration](#configuration)
- [Run](#run)

## How it works

Channel Bridge adds a layer to Channel-Sender providing:

1. **Authorization**

    Sender's Rest endpoint provides logic to generate a channel identifier (channel reference) and a channel secret. As this endpoint has no auth or authz logic, Channel brige fills this gap serving as a proxy for Sender's endpoint adding auth logic (eg. validating user creds). This way sender's rest endpoint can remain private and not publicly available. 


    ```mermaid
    sequenceDiagram
        autonumber
        SPA / Mobile App->>+ADF Channel Bridge: Hello I wish to register a channel to receive async events.
        ADF Channel Bridge->>ADF Channel Bridge: Perform validations
        ADF Channel Bridge->>+ADF Channel Sender: Perfect!, please generate  channel ref and secret
        ADF Channel Sender-->>-ADF Channel Bridge: sure, here you go...
        ADF Channel Bridge-->>-SPA / Mobile App: Your ref and secret sir
        SPA / Mobile App->>SPA / Mobile App: Ok, now I'm ready to open this channel
    ```

    Steps:

    (1) clients will need to provide information to identify this channel, for example: the application name or Id, the user name, and an alias to this channel. Also present some credentials.

    (2) Channel bridge performs authentication e.g. Validating a JWT in the `authorization` header.

    (3) Sender's rest endpoint, is called to obtain a channel reference (ref) and a secret to physically open the channel later.

    (6) client persist this tuple (Ref, Secret) for the next phase. 

    Additional details about this process can be read [here](./docs/channel_authentication.md).


2) **Openning a channel**

    Once the client has obtained a channel reference and a secret, can proceed to open the channel.

    ```mermaid
    sequenceDiagram
        autonumber
        SPA / Mobile App->>+ADF Channel Sender: (websocket) Open channel with this `ref` 
        ADF Channel Sender->>ADF Channel Sender: OK, ref is valid
        ADF Channel Sender-->>SPA / Mobile App: ok, it's open.
        SPA / Mobile App->>ADF Channel Sender: (Websocket) I'm sending my `secret`.
        ADF Channel Sender->>ADF Channel Sender: Secret is validated
        ADF Channel Sender-->>-SPA / Mobile App: ok, everithing's good, leaving channel open.
        Note right of SPA / Mobile App: Now I'm ready to receive events!
    ```

    Steps:

    (1) Client having obtained a channel ref and secret opens the websocket connection.

    (2) Sender validates the ref and verifies its was previuosly generated.

    (3) Sender leaves channel open and waits (for a small time windows) for the secret to be sent by the client.

    (4) Client sends secret

    (5) Sender verifies the secret

    (6) if checks out, the channel is left open, in any other case, connection will be closed by the server.

    See details about channel opening process [here](./docs/channel_opening.md).


3. **Message Routing**

    Any component in your backend architecture can route messages to any connected front-end, by publishing an event to a Message Broker or Event Bus.

    ```mermaid
    sequenceDiagram
        autonumber
        activate Backend Service
        Backend Service->>Backend Service: Some bussiness logic performed.
        Backend Service->>RabbitMQ: Publish an event <br>with an specific payload.
        deactivate Backend Service
        activate RabbitMQ
        RabbitMQ -)ADF Channel Bridge: Event subscribed!
        deactivate RabbitMQ
        activate ADF Channel Bridge
        ADF Channel Bridge->>ADF Channel Bridge: Check payload for a channel <br>alias and search for an<br>existing channel registered.
        ADF Channel Bridge-)ADF Channel Sender: Yay! There is a channel<br>with that alias, please<br>deliver this message.
        deactivate ADF Channel Bridge
        activate ADF Channel Sender
        ADF Channel Sender-)+SPA / Mobile App: Here is your event!
        SPA / Mobile App-->>-ADF Channel Sender: ACK
        deactivate ADF Channel Sender
    ```

    Steps:

    (1 & 2) Some backend process or service performs an operation and as s result an event is published to an event broker.

    (3 & 4) The event is ingested by Channel Bridge, and inspect the message payload for a pre-configured path in order to extract some data to be considered a channel alias.

    (5 & 6) if the alias actually exists and is linked to a channel opened by a client, then Channel Sender will be instructed to deliver the message via such channel.

    (7) the client ACKs the message (or redelivery will be performed until message is ack'ed).

    Please see [Message routing](./docs/message_routing.md) for more information on routing.


## Install

### Requirements

- Elixir >= 1.15
- Mix

### Compile

```elixir
mix deps.get
mix compile
```

## Configuration

- For local dev environment, open and edit the `config-local.yaml` file to set up configurations.
- Make sure `config\dev.exs` contains the path to file to use.

  ```elixir
  config :bridge_core,
  env: Mix.env(),
  config_file: "./config-local.yaml"
  ```

## Run

In the shell:

```bash
$ iex -S mix
```

or to run several instances locally

```bash
$ MIX_ENV=<ENV-NAME> iex --erl "-name channel_bridge_ex0@127.0.0.1" -S mix

```

### Connect nodes in erlang cluster in k8s

ADF Bridge incorporate `libcluster` dependency in order to facilitate the automatic configuration of erlang clusters in kubernetes.

In folder [deploy_samples\k8s](./deploy_samples/k8s/README.md) we have included manifests to deploy ADF sender on kubernetes (and also if istio is present), using 3 of the strategies supported by `libcluster`.
