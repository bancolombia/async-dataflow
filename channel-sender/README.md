# Channel Sender

[![Docker Hub](https://img.shields.io/docker/pulls/bancolombia/async-dataflow-channel-sender?label=Docker%20Hub)](https://hub.docker.com/repository/docker/bancolombia/async-dataflow-channel-sender)

- [Requirements](#requirements)
- [Install](#install)
- [Configuration](#configuration)
- [Run](#run)
- [Clients](#clients)

Distributed Elixir Cluster implementation of real time with websockets and notifications channels.

This service is part of the Async Dataflow project, which is a set of tools to facilitate the implementation 
of real-time applications.

Channel sender main purpose is to allow backend services to send messages via a real time channel (websocket) to your 
front end application(s) (web or mobile). Enabling you to implement real time notifications, updates, etc.

```mermaid
flowchart LR
  subgraph  
  A(Backend service) -- send message --> B[ADF channel sender]
  A2(Backend service) -- send message --> B
  A3(Backend service) -- send message --> B
  end
  B -- send message --> C(Front end application)
```

See detailed [docs](docs/main.md) for more information.

## Requirements

- Elixir >= 1.16
- Mix

## Install

```elixir
mix deps.get
mix compile
```

## Run

In the shell:

```bash
$ iex -S mix
```

or to run several instances locally

```bash
$ MIX_ENV=<CONFIG-FILE-NAME> iex --erl "-name async-node1@127.0.0.1" -S mix

```

## Clients

| Repository |
| -- |
|[Javascript](https://github.com/bancolombia/async-dataflow/tree/master/clients/client-js)|
