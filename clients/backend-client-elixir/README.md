# ADF Channel Sender Connector

This package provides an elixir connector to the API exposed by [Channel-Sender]().

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `adf_sender_connector` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:adf_sender_connector, "~> 1.0.0"}
  ]
end
```

## Usage

### Registering a channel

```elixir
{:ok, response} = 
   AdfSenderConnector.channel_registration("app_ref", "user_ref")
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
  {:ok, %{channel_ref: "channel.xxx1", channel_secret: "channel.s3crt.xyz"}}
```

### Requesting Message Delivery

You can request `Channel sender` to deliver a message via a channel previously 
registered (and opened from the web o mobile clients UI).

You can use the `route_message/1` function which receives:

  - `message`:   This is a `%Message{}` struct.

Example:

```elixir
alias AdfSenderConnector.Message

payload_to_route  %{"hello" => "world"}

# You can use the Message struct and define all of its properties.
message =  Message.new("channel.ref000", "custom.message.id", 
    "custom.correlation.id", payload_to_route, "event.name")

{:ok, response} = AdfSenderConnector.route_message(message)
```







