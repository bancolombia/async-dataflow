defmodule BridgeRestapiAuth.Oauth.Strategy do

  use JokenJwks.DefaultStrategyTemplate

  def init_opts(opts), do: Keyword.merge(opts, jwks_url: BridgeRestapiAuth.Oauth.Config.jwks_url())

end
