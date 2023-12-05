# Channel Bridge

Distributed Elixir Cluster implementation of a async messages router.

- [How it works](#how-it-works)
- [Install](#install)
- [Configuration](#configuration)
- [Run](#run)

## How it works

Channel Bridge adds a layer to Sender providing authorization functionality. 

```mermaid
    C4Component
    Component(spa, "Single Page Application", "javascript and angular", "Customers via their web browser.")
    Component(ma, "Mobile App", "Flutter", "Customers using their mobile mobile device.")

    Container_Boundary(xx, "ADF") {
        Component(bridge, "Channel Bridge", "Rest Endpoint", "Validate user credentials")
        Component(sender, "Channel Sender", "Rest Endpoint", "Handles channel registration")

        Rel(bridge, sender, "exchange creds", "JSON/HTTPS")
    }

    Rel(spa, bridge, "Presents user creds", "JSON/HTTPS")
    Rel(ma, bridge, "Presents user creds", "JSON/HTTPS")
    

    UpdateRelStyle(spa, bridge, $offsetX="-110", $offsetY="40")
    UpdateRelStyle(ma, bridge, $offsetX="80", $offsetY="-40")
    UpdateRelStyle(bridge, sender,  $offsetX="-40", $offsetY="-40")

```

Once the channel credentials have been obtained:

```mermaid
    C4Component
    Component(spa, "Single Page Application", "javascript and angular", "Customers via their web browser.")
    Component(ma, "Mobile App", "Flutter", "Customers using their mobile mobile device.")

    Container_Boundary(xx, "ADF") {
        Component(bridge, "Channel Bridge", "", "")
        Component(sender, "Channel Sender", "Websocket Endpoint", "Handle channels")

    }

    Rel(spa, sender, "Open realtime channel", "Websocket")
    Rel(ma, sender, "Open realtime channel", "Websocket")
    
    UpdateRelStyle(spa, sender, $offsetX="-170", $offsetY="-40")
    UpdateRelStyle(ma, sender, $offsetX="10", $offsetY="-40")
```

Message Flow:

```mermaid
    C4Component
    Component(spa, "Single Page Application", "javascript and angular", "Customers via their web browser.")
    Component(ma, "Mobile App", "Flutter", "Customers using their mobile mobile device.")

    Container_Boundary(b, "Application Backend") {
        Component(backend, "Backend App", "", "Executes some logic")
        Component(ev, "Event Broker", "", "Eg: RabbitMQ")
    }

    Container_Boundary(a, "ADF") {
        Component(bridge, "Channel Bridge", "", "Event suscriber")
        Component(sender, "Channel Sender", "Websocket Endpoint", "Handle channels")
    }

    Rel(sender, spa, "message pushed", "Websocket")
    Rel(sender, ma, "message pushed", "Websocket")
    Rel(backend, ev, "event emitted", "")
    Rel(ev, bridge, "message pulled", "")
    Rel(bridge, sender, "Call route endpoint", "JSON/HTTPS")
    
    UpdateRelStyle(backend, ev, $offsetX="-34", $offsetY="-20")
    UpdateRelStyle(ev, bridge, $offsetX="-34", $offsetY="-20")
    UpdateRelStyle(bridge, sender, $offsetX="-45", $offsetY="-20")
    UpdateRelStyle(sender, spa, $offsetX="-100", $offsetY="-60")
    UpdateRelStyle(sender, ma, $offsetX="10", $offsetY="-60")
```



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

Open and edit the `config.yaml` file to set up configurations.

## Run

In the shell:

```bash
$ iex -S mix
```

or to run several instances locally

```bash
$ MIX_ENV=<CONFIG-FILE-NAME> iex --erl "-name async-node1@127.0.0.1" -S mix

```

### Connect nodes in erlang cluster in k8s

ADF Bridge incorporate `libcluster` dependency in order to facilitate the automatic configuration of erlang clusters in kubernetes.

In folder [deploy_samples\k8s](./deploy_samples/k8s/README.md) we have included manifests to deploy ADF sender on kubernetes (and also if istio is present), using 3 of the strategies supported by `libcluster`.
