defmodule ChannelSenderEx.Transport.EntryPoint do
  @moduledoc """
  Configure application web entry points
  """
  alias ChannelSenderEx.Transport.Socket

  def routes() do
    [
      {:external_server, ext_port(),
       [
         {"/ext/socket", Socket, []}
       ]},
      {:internal_server, int_port(),
       [
         {"/ext/channel/create", Socket, []},
         {"/ext/channel/deliver_message", Socket, []}
       ]}
    ]
  end

  defp ext_port(), do: 8082
  defp int_port(), do: 8086
end
