defmodule BridgeRestapiAuth.Oauth.Token do
  use Joken.Config, default_signer: nil

  add_hook(JokenJwks, strategy: BridgeRestapiAuth.Oauth.Strategy)

  @impl true
  def token_config do
    default_claims(skip: [:aud, :iss])
    |> add_claim("iss", nil, &issued_by_domain?/1)
    |> add_claim("aud", nil, &has_custom_api_audience?/1)
  end

  def issued_by_domain?(iss), do: validate_contained(iss, BridgeRestapiAuth.Oauth.Config.iss())
  def has_custom_api_audience?(aud), do: validate_contained(aud, BridgeRestapiAuth.Oauth.Config.aud())

  defp validate_contained(value, configured_values) when is_list(value) do
    Enum.all?(value, &(&1 in configured_values))
  end

  defp validate_contained(value, configured_values), do: validate_contained([value], configured_values)

end
