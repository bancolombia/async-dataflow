defmodule BridgeRestapiAuth.Oauth.Config do
  @moduledoc """
  Configuration for the OAuth2.0 authenticator.
  """

  def iss, do: cfg() |> Map.get("allowed_issuers")

  def aud, do: cfg() |> Map.get("allowed_audiences")

  def jwks_url, do: cfg() |> Map.get("jwks")

  # def json_library, do: Jason

  defp cfg, do: get_in(Application.get_env(:channel_bridge, :config), [:bridge, "channel_authenticator", "config"])

end
