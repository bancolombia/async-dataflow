defmodule StreamsApi.Rest.BaseRouter do
  @moduledoc false

  use Plug.Router
  use Plug.ErrorHandler

  plug(:match)
  plug(:dispatch)

  forward("/api/v1/channel-streams-ex", to: StreamsApi.Rest.RestRouter)

  match(_, do: send_resp(conn, 404, "Resource not found"))

end
