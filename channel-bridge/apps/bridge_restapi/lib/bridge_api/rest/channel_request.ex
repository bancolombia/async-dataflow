defmodule BridgeApi.Rest.ChannelRequest do
  defstruct ~w[req_headers req_params body token_claims]a

  @moduledoc """
  A new channel request data
  """
  alias BridgeCore.Utils.JsonSearch
  alias BridgeCore.AppClient
  alias BridgeCore.User
  alias BridgeCore.CloudEvent.Extractor

  require Logger

  @default_sessionid_search_path "$.req_headers['sub']"
  @default_app_ref "default_app"
  @default_user_ref "default_user"

  @type headers_map() :: map()
  @type params_map() :: map()
  @type body_map() :: map()
  @type claims_map() :: map()

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

  @spec extract_channel_alias(t()) :: {:ok, binary()} | {:error, any()}
  def extract_channel_alias(request_data) do

    request_channel_alias =
      BridgeHelperConfig.get([:bridge, "request_channel_identifier"], @default_sessionid_search_path)

    ch_alias =
      request_data
      |> JsonSearch.prepare()
      |> JsonSearch.extract(request_channel_alias)

    case ch_alias do
      e when e in [nil, "undefined"] -> {:error, :nosessionidfound}
      _ -> {:ok, ch_alias}
    end
  end

  @spec extract_application(t()) :: {:ok, AppClient.t()} | {:error, any()}
  def extract_application(request_data) do
    app_key = BridgeHelperConfig.get([:bridge, "request_app_identifier"], @default_app_ref)
    |> (fn x ->
      case String.starts_with?(x, "$.") do
        true -> {:lookup, x}
        false -> {:fixed, x}
      end
    end).()

    app =
      case apply_strategy(app_key, request_data) do
        {:ok, app_id} ->
          AppClient.new(app_id, "")

        {:error, err} ->
          Logger.warning(
            "missing application info in request, #{inspect(app_key)} = #{err}. Data: #{inspect(request_data)}"
          )

          AppClient.new(@default_app_ref, "")
      end

    {:ok, app}
  end

  @spec extract_user_info(t()) :: {:ok, User.t()} | {:error, any()}
  def extract_user_info(request_data) do
    user_key = BridgeHelperConfig.get([:bridge, "request_user_identifier"], @default_user_ref)
    |> (fn x ->
      case String.starts_with?(x, "$.") do
        true -> {:lookup, x}
        false -> {:fixed, x}
      end
    end).()

    user =
      case apply_strategy(user_key, request_data) do
        {:ok, user_id} ->
          User.new(user_id)

        {:error, err} ->
          Logger.warning(
            "missing user info in request, #{inspect(user_key)} = #{err}. Data: #{inspect(request_data)}"
          )

          User.new(@default_app_ref)
      end

    {:ok, user}

  end

  defp apply_strategy(config, data) do
    case config do
      {:fixed, fixed_value} ->
        # uses a fixed string value as application reference
        {:ok, fixed_value}

      {:lookup, key_to_search} ->
        # searches for a key in user data map
        Extractor.extract(data, key_to_search)
    end
  end

end
