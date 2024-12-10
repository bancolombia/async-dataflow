defmodule ChannelSenderEx.Transport.EntryPoint do
  @moduledoc """
  Configure application web entry points
  """
  alias ChannelSenderEx.Transport.CowboyStarter
  alias ChannelSenderEx.Transport.Socket

  def start(port \\ ext_port()) do
    routes(port) |> CowboyStarter.start_listeners()
  end

  def routes(port) do
    [
      {:external_server, port,
       [
         {"/ext/socket", Socket, []},
         #Enable below line for load testing purposes
         {:_, Plug.Cowboy.Handler, {ChannelSenderEx.Transport.Rest.RestController, []}}
       ]}
    ]
  end

  defp ext_port, do: Application.get_env(:channel_sender_ex, :socket_port, 8082)
end
