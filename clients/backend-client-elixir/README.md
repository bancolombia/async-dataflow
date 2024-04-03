# ADF Channel Sender Connector

This package provides an elixir connector to the API exposed by [Channel-Sender]().

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `adf_sender_connector` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:adf_sender_connector, "~> 0.3.0"}
  ]
end
```

## Usage

In the most typical use of this client, you only need to add it as a child of your
application. If you created your project via `Mix` (passing the `--sup` flag) this
is handled in `lib/my_app/application.ex`. This file will already contain an empty
list of children to add to your application - simply add entries for your 
connector to this list:

```elixir
children = [
  AdfSenderConnector.spec([sender_url: "http://localhost:8888"]),
  AdfSenderConnector.registry_spec()
]
```

This will add to the list of superviced processes, the connector process itself 
and a registry of active channels.

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
- A keyword list of options

  - `http_opts` : (Optional) List of HTTPoison Request options to be used in the
    connection and requests. Options are described 
    in [HTTPoison docs](https://hexdocs.pm/httpoison/HTTPoison.Request.html).

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

You can use either the `route_message/3` function:

  - `channel_ref`: The channel reference (or ID) obtained from the registration
    process.
  - `event_name` : The event name, wich will act as a routing key.
  - `message`:   This can be either a %Message{} struct or a Map.

Example 1:

```elixir
alias AdfSenderConnector.Message

payload_to_route  %{"hello" => "world"}

# You can use the Message struct and define all of its properties.
message =  Message.new("channel.xxx1", "custom.message.id", 
    "custom.correlation.id", payload_to_route, "event.name")

{:ok, response} = AdfSenderConnector.route_message("channel.xxx1", "event.name", message)
```

Example 2:

```elixir
payload_to_route  %{"hello" => "world"}

# a default %Message{} struct will be constructed on the fly, with a random message_id, and nil
# correlation id.
{:ok, response} = AdfSenderConnector.route_message("channel.xxx1", "event.name", payload_to_route)
```






