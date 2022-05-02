# ADF Channel Sender Connector

This package provides an elixir connector to the API exposed by [Channel-Sender]().

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `adf_sender_connector` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:adf_sender_connector, "~> 0.1.0"}
  ]
end
```

## Usage

In the most typical use of this client, you only need to add it as a child of your application. If you created your project via `Mix` (passing the `--sup` flag) this is handled in `lib/my_app/application.ex`. This file will already contain an empty list of children to add to your application - simply add entries for your connector to this list:

```elixir
children = [
  {AdfSenderConnector, [name: :my_adf_sender, base_url: "http://sender.server:8082"}
]
```

If you wish to start a process manually (for example, in iex), you can just use `AdfSenderConnector.start_link/2`:

```elixir
AdfSenderConnector.start_link([name: :my_adf_sender, base_url: "http://sender.server:8082"])
```

Options:

- name: An `Atom` identifying the process.
- base_url: The base url for the running instance of `Channel Sender`.

### Registering a channel

```elixir
{:ok, response} = AdfSenderConnector.create_channel(:my_adf_sender, "app_ref", "user_ref")
```

Args:

- An `Atom` as the connector identifier.
- Application reference, the identifier of the application for which a channel is being registered.
- User reference, the reference of the user for whom the channel is being registered.

The registering channel response is a `Map` containing the channel reference and the secret needed in the frond end to actually create a tcp connection with the sender and authenticate it.

Response example:

```elixir
  {:ok, %{channel_ref: "xxx", channel_secret: "yyy"}}
```

### Requesting Message Delivery

You can request `Channel sender` to deliver a message via a channel previously registered (and opened from the web o mobile clients UI).

You can use either the `deliver_message/2` function:


```elixir
alias AdfSenderConnector.Message

payload_to_route  %{"hello" => "world"}

# You can use the Message struct and define all of its properties.
message =  Message.new("channel.ref", "custom.message.id",
  "custom.correlation.id", payload_to_route, "event.name")

{:ok, response} = AdfSenderConnector.deliver_message(:my_adf_sender, message)
```

Or with the `deliver_message/4` function:

```elixir
payload_to_route  %{"hello" => "world"}

# this function will build a Message struct with random message id and a nil correlation id.
{:ok, response} = AdfSenderConnector.deliver_message(:my_adf_sender, "channel_ref", 
  "event.name", payload_to_route)
```





