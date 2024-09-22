defmodule StreamsRestapiAuth.Oauth.Strategy do
  @moduledoc """
  Strategy for handling the OAuth2.0 token.
  """

  alias StreamsRestapiAuth.Oauth.Config
  use JokenJwks.DefaultStrategyTemplate

  def init_opts(opts), do: Keyword.merge(opts, jwks_url: Config.jwks_url())

end
