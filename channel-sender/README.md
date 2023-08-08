# Channel Sender

[![Docker Hub](https://img.shields.io/docker/pulls/bancolombia/async-dataflow-channel-sender?label=Docker%20Hub)](https://hub.docker.com/repository/docker/bancolombia/async-dataflow-channel-sender)
![imagen](https://user-images.githubusercontent.com/12372370/137362047-34f5d048-9f1a-4065-8a09-dc97318bf42e.png)

Distributed Elixir Cluster implementation of real time with websockets and notifications channels.

- [Channel Sender](#channel-sender)
- [How to use](#how-to-use)
  - [Install](#install)
  - [Configuration](#configuration)
  - [API Documentation](#configuration)
  - [Run](#run)
- [Clients](#clients)

## How to use

### Requirements

- Elixir >= 1.12
- Mix

### Install

```elixir
mix deps.get
mix compile
```

### Configuration

Open and edit the `config.yaml` file to set up configurations.
| **Parameters** | Description | Default Value |
| -------------------------------- | -------------------------------------- | ------------------ |
| `socket_port` | Port to atend Web Sockets requests | 8082 |
| `rest_port` | API Port to atend Rest service requests | 8081 |
| `initial_redelivery_time` | time in milliseconds to retry when an ack is not received after send an event| 900 |
| `socket_idle_timeout` | timeout in milliseconds to reject idle socket | 30000 |
| `max_age` | Max time in seconds of validity for the secret **the channel sender have strategy to update the secret before this expire.** | 900 |

### API Documentation

`doc/swagger.yaml` A Swagger definition of the API.

Run make `https://editor.swagger.io/` add the `swagger.yaml` file and you get a preview the documentation.

### Run

In the shell:

```bash
$ iex -S mix
```

or to run several instances locally

```bash
$ MIX_ENV=<CONFIG-FILE-NAME> iex --erl "-name async-node1@127.0.0.1" -S mix

```

### Connect nodes in erlang cluster in k8s

ADF Sender incorporate `libcluster` dependency in order to facilitate the automatic configuration of erlang clusters in kubernetes.

In folder [deploy_samples\k8s](./deploy_samples/k8s/README.md) we have included manifests to deploy ADF sender on kubernetes (and also if istio is present), using 3 of the strategies supported by `libcluster`.

## Clients

| Repository |
| -- |
|[Javascript](https://github.com/bancolombia/async-dataflow/tree/master/clients/client-js)|
