# Async Dataflow Channel Bridge/Router

## Contents

- [What is ADF Channel Bridge](#what-is-adf-channel-bridge)
- [How to use](#how-to-use)

## What is ADF Channel Bridge

This module serves two functions:

- Like a gate keeper for [Async Dataflow Channel Sender](https://github.com/bancolombia/async-dataflow/tree/master/channel-sender) rest services.

  - **ADF Channel Bridge** serves as a secured mechanism for registering channels with **ADF Channel Sender**, exposing a rest endpont. This endpoint should be secured with the apropriate authentication mechanism. For example exposing such endpoint via a secured gateway and checking for a valid bearer token. Of course you can also implement your own auth flows.
  - As a result of a successful auth process, **ADF Channel Bridge** calculates (with data present in the request headers, the bearer token claims(if present), and/or body) an unique tuple of `user_ref` / `app_ref` to forward the channel registration to **ADF channel sender**. You can configure what data should ADF Bridge use to build such tuple.
  - Obtain the credentials `channel_ref` / `channel_secret` provided by **ADF channel sender**, and link them with an user provided identifier.
  - Return credentials to caller. Caller uses this credentials to physically open the socket with **ADF channel sender**, using any of the available clients ([Javascript](https://github.com/bancolombia/async-dataflow/tree/master/clients/client-js), [Dart](https://github.com/bancolombia/async-dataflow/tree/master/clients/client-dart)).

- Also can serve like a Router, listening for events in the event bus (RabbitMQ) and:

  - Inspect each event looking for certain data (Configured JSON paths), trying to identify if such event should be relayed via ADF Sender as an asynchronous response.
  - Obtains the user provided session identifier in such event.
  - Determines if there's a channel registered for such session-id, and If such a channel exists, then delivers the cloud event to the front end client via **ADF channel sender** appropiate rest endpoint.

**IMPORTANT**: What AsyncDataflow Channel Bridge doesn't do:

- Create or Manage TCP connections with clients.
- Garantee client connection or reconnection of TCP sockets

Those are resposability of [Async Dataflow Channel Sender](https://github.com/bancolombia/async-dataflow/tree/master/channel-sender) and/or avaliable clients.


## How to run

### Requirements

- Elixir >= 1.10
- Mix

Infraestructure:
- You need a running instance of `Async DataFlow Channel Sender`.
- Also an instance of RabbitMQ with a specific exchange, binding name and queue.
- All of those configured in the `config.yaml` file.

### Compile
```bash
mix deps.get
mix compile
```
### Configuration

Open and edit the `config.yaml` file to set relevant attributes.

TODO: _complete documentation of configuration properties._

### Run
In the shell:
```bash
iex -S mix 
```
or
```bash
 MIX_ENV=<CONFIG-FILE-NAME> iex --erl "-name bridge-node<NUMBER>@127.0.0.1" -S mix 
 ```
 ### Connect nodes
Can connect the nodes with a self-discovery strategy as a central register or broadcast, you can also connect the nodes manually with the following task. **this task is useful in development environment.**
```elixir
iex1> Node.connect(:"node-name@ip")
 ```
 and verify with:
 ```elixir
 iex1> Node.list()
 ```

## How to use

### Register a channel

Calling  `/api/v1/channel-bridge-ex/ext/channel` endpoint will handle the channel registration with `Channel Sender`.

Example:

```shell
curl --location 
  --request POST 'http://localhost:8083/api/v1/channel-bridge-ex/ext/channel' \
  --header 'application-id: xyz' \
  --header 'session-tracker: foo'
```

The response should be:

```json
{
    "result": {
        "channel_ref": "2769cf3xxxxxxxx.d0292db518a7xxxxxxxxxx",
        "channel_secret": "xxxxx.xxxxxxxxxxx.xxxxxxxxxxxxxx",
        "session_tracker": "foo"
    }
}
```

With these credentials you can now open the channel in the frond end, using any of the available clients ([Javascript](https://github.com/bancolombia/async-dataflow/tree/master/clients/client-js), [Dart](https://github.com/bancolombia/async-dataflow/tree/master/clients/client-dart)).

### API Documentation
`doc/swagger.yaml` A Swagger definition of the API.

Run make `https://editor.swagger.io/` add the `swagger.yaml` file and you get a preview the documentation.


### Route a message


Routing a message is done via publishing a message to a topic in rabbitMQ, with the appropriate routing key, 
to the queue where channel bridge is listening to.

Example:

```
Topic Foo -> Routing key 'bussines.event.#' -> Queue Bar
```

Topic name, Queue name and routing key are part of the channel bridge configuration.


The message is expected to be consistent with an [Cloud event](https://github.com/cloudevents/spec/blob/v1.0.2/cloudevents/spec.md). 

Example:

```json
{
  "data": {
      "msg": "Hello World, Much Wow!"
  },
  "dataContentType": "application/json",
  "id": "A234-1234-1234",
  "source": "https://organization.com/cloudevents/operation",
  "specVersion": "1.0",
  "time": "2018-04-05T17:31:00Z",
  "subject": "foo",
  "type": "bussines.event.transaction.completed"
}
```

Notice the `subject` key. If this value matches a previusly registered channel `session_tracker` ID, then the message will be routed to the client via the physical channel connection opened from the frontend.


## Health Endpoints

`/liveness` and `/readiness` endpoints are available to use as probes on K8S deployments.

## Metrics endpoint

A `/metrics` endpoint its available, to fetch diferent metrics and export them to other tools, for example, **Prometheus**.

### Available metrics

Multiple erlang VM and other tools metrics are available at such endpoint,  including our own defined metrics:

|Metric|Type|Description|
|---|---|---|
|adfcb_broadway_msg_count|Counter|count of messages received from rabbitmq by broadway (the tool for streaming messages).|
|adfcb_broadway_err_count|Counter|count of errors receiving messages from broadway|
|adfcb_cloudevent_parse_count|Counter|counter for messages succesfully parsed as CloudEvents.|
|adfcb_cloudevent_parse_fail_count|Counter|counter for CloudEvent Messages Failed to parse|
|adfcb_cloudevent_failed_mutations_count|Counter|Counter for errors performing mutations to CloudEvent Messages, for example, homologating error codes.|
|adfcb_channel_alias_missing|Counter|Counter for messages not having an alias. So delivery is not possible.|
|adfcb_channel_noproc_count|Counter|Counter for errors when looking for a channel process linked to an alias, but the process does not exist. In this case delivery of a message is also not possible.|
|adfcb_sender_request_channel_count|Counter|Counter for channel registration requests sent to ADF sender.|
|adfcb_sender_request_channel_fail_count|Counter|Counter for failures requesting channel registration to ADF sender.|
|adfcb_sender_delivery_count|Counter|Counter for message routing requests sent to ADF sender.|
|adfcb_sender_delivery_fail_count|Counter|Counter for failures requesting delivering a message to ADF sender. In this case the request for delivering a message was made to ADF sender, but ADF sender was not available o returned an error response.|
|adfcb_plug_request_count|Counter|Counter of rest requests received to any of the Bridge endpoints|
