defmodule BridgeApi.Rest.BaseRouter do
  @moduledoc """
  """

  use Plug.Router
  use Plug.ErrorHandler

  plug(:match)
  plug(:dispatch)

  forward("/api/v1/channel-bridge-ex", to: BridgeApi.Rest.RestRouter)

  match(_, do: send_resp(conn, 404, "Resource not found"))

end
