defmodule ChannelBridgeEx.Core.Channel.ChannelRequest do
  defstruct ~w[req_headers req_params body token_claims]a

  @moduledoc """
  A new channel request data
  """
  alias ChannelBridgeEx.Utils.JsonSearch
  alias ChannelBridgeEx.Core.AppClient
  alias ChannelBridgeEx.Core.User

  require Logger

  @type headers_map() :: Map.t()
  @type params_map() :: Map.t()
  @type body_map() :: Map.t()
  @type claims_map() :: Map.t()

  @type t() :: %__MODULE__{
          req_headers: headers_map(),
          req_params: params_map(),
          body: body_map(),
          token_claims: claims_map()
        }

  @doc """
  Creates a Channel Request by consolidating request data.
  """
  @spec new(headers_map(), params_map(), body_map(), claims_map()) :: t()
  def new(req_headers, req_params, body, token_claims) do
    %__MODULE__{
      req_headers: req_headers,
      req_params: req_params,
      body: body,
      token_claims: token_claims
    }
  end

  @spec extract_channel_alias(t()) :: {:ok, String.t()} | {:error, any()}
  def extract_channel_alias(request_data) do

    request_channel_alias =
      Application.get_env(
        :channel_bridge_ex,
        :request_channel_identifier,
        "$.req_headers['session-tracker']"
      )

    ch_alias =
      request_data
      |> JsonSearch.prepare()
      |> JsonSearch.extract(request_channel_alias)

    case ch_alias do
      nil -> {:error, :nosessionidfound}
      _ -> {:ok, ch_alias}
    end
  end

  @spec extract_application(t()) :: {:ok, AppClient.t()} | {:error, any()}
  def extract_application(request_data) do
    AppClient.from_ch_request(request_data)
  end

  @spec extract_user_info(t()) :: {:ok, User.t()} | {:error, any()}
  def extract_user_info(request_data) do
    User.from_ch_request(request_data)
  end
end
