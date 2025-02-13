# ADF Channel Sender Connector

This package provides an elixir connector to the API exposed by [Channel-Sender]().

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `adf_sender_connector` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:adf_sender_connector, "~> 0.4.0"}
  ]
end
```

## Usage

### Configuration

The configuration is done in the `config.exs` file of your application. The following configuration options are available:

```elixir
config :adf_sender_connector,
  base_path: "http://sender.server:8081"
```

Also, Declare this child spec in your application supervisor: 

```elixir
children = [
  AdfSenderConnector.http_client_spec()
]
```

### Registering a channel

```elixir
{:ok, response} = AdfSenderConnector.channel_registration("app_ref", "user_ref")
```

Args:
- Application reference, a binary identifier of the application for which a 
  channel is being registered.
- User reference, a binary identifier of the user for whom the channel is
  being registered.

The registering channel response is a `Map` containing the channel reference and 
a secret. This data is needed in the frond end of your application, to actually
create a tcp connection with the sender and authenticate it.

Response example:

```elixir
  {:ok, %{"channel_ref" => "channel.xxx1", "channel_secret" => "channel.s3crt.xyz"}}
```

### Closing a channel

```elixir
{:ok, response} = AdfSenderConnector.channel_close("channel.xxx1")
```

Args:
- channel reference: a binary identifier of the previously registered channel.

Response example:

```elixir
  {:ok, %{"result" => "Ok"}}
```


### Requesting Message Delivery

You can request `Channel sender` to deliver a message via a channel previously 
registered.

You can either use the `route_message/5` function:

  - `channel_ref`: The channel reference (or ID) obtained from the registration
    process.
  - `message_id`: The message unique ID.
  - `correlation_id`: The message correlation ID (optional).
  - `data`:   The data or payload you would like to deliver.
  - `event_name` : The event name, wich will act as a routing key.

Example:

```elixir
alias AdfSenderConnector.Message

{:ok, response} = AdfSenderConnector.route_message(
  "channel.xxx1", "custom.message.id", "custom.correlation.id",
   %{"hello" => "world"}, "event.name")
```

Or use the `route_message/1` function:

  - `message`: A Message struct.

Example:

```elixir
alias AdfSenderConnector.Message

# You can use the Message struct and define all of its properties.
message =  Message.new("channel.xxx1", "custom.message.id", 
    "custom.correlation.id", %{"hello" => "world"}, "event.name")

{:ok, response} = AdfSenderConnector.route_message(message)
```


Or use the `route_batch/1` function:

- `messages`: A list of Message structs.

```elixir
alias AdfSenderConnector.Message

# You can use the Message struct and define all of its properties.
messages = [
  Message.new("channel.xxx1", "message.id.1", "custom.correlation.id", "hello", "event.name"),
  Message.new("channel.xxx1", "message.id.2", "custom.correlation.id", "world", "event.name"),
  ... up to 10 messages ...
]

{:ok, response} = AdfSenderConnector.route_batch(messages)
```

- You can send up to 10 messages in batch mode. 
- Messages will be validated for required fields
- Any message to fail the validation will be excluded from the batch.



