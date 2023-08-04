defmodule ChannelSenderEx.Core.ChannelIDGenerator do
  @moduledoc """
  Generate unique and efficient channel Ids
  """

  import Application, only: [get_env: 2]
  import Plug.Crypto, only: [verify: 4, sign: 3]
  alias ChannelSenderEx.Core.RulesProvider

  @type application() :: String.t()
  @type user_ref() :: String.t()
  @type channel_ref() :: String.t()
  @type channel_secret() :: String.t()

  def generate_channel_id(app_id, user_id) do
    "#{UUID.uuid3(:dns, "#{app_id}.#{user_id}", :hex)}.#{UUID.uuid4(:hex)}"
  end

  def generate_token(channel_ref, app_id, user_id) do
    {secret, salt} = get_secret_and_salt!()
    sign(secret, salt, {channel_ref, app_id, user_id})
  end

  @type token_error_reason() ::
          :expired | :invalid | {:different_channel, channel_ref(), application(), user_ref()}
  @spec verify_token(channel_ref(), channel_secret()) ::
          {:ok, application(), user_ref()} | {:error, token_error_reason()}
  def verify_token(channel_ref, channel_secret) do
    {secret, salt} = get_secret_and_salt!()

    case verify(secret, salt, channel_secret, max_age: max_age()) do
      {:ok, {^channel_ref, app_id, user_id}} ->
        {:ok, app_id, user_id}

      {:ok, {channel_ref, app_id, user_id}} ->
        {:error, {:different_channel, channel_ref, app_id, user_id}}

      {:error, :expired} ->
        {:error, :expired}

      {:error, :invalid} ->
        {:error, :invalid}

      other ->
        raise "Error in token verification #{inspect(other)}"
    end
  end

  defp get_secret_and_salt!() do
    case get_env(:channel_sender_ex, :secret_base) do
      data = {_secret, _salt} -> data
      other -> raise "Secret base no properly configured for application: #{other}"
    end
  end

  defp max_age(), do: RulesProvider.get(:max_age)
end
