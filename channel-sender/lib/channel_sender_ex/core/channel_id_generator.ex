defmodule ChannelSenderEx.Core.ChannelIDGenerator do
  @moduledoc """
  Generate unique and efficient channel Ids
  """

  import Application, only: [get_env: 2]
  import Plug.Crypto, only: [verify: 4, sign: 4]
  alias ChannelSenderEx.Core.RulesProvider

  @type application() :: String.t()
  @type user_ref() :: String.t()
  @type channel_ref() :: String.t()
  @type channel_secret() :: String.t()

  @seconds_to_millis 1_000

  def generate_channel_id(app_id, user_id) do
    UUID.uuid5(UUID.uuid4(:default), "#{app_id}.#{user_id}", :hex)
  end

  def generate_token(channel_ref, app_id, user_id) do
    {secret, salt} = get_secret_and_salt!()
    signed_at = System.os_time(:millisecond)
    max_age = max_age()
    valid_until = signed_at + max_age * @seconds_to_millis
    opts = [signed_at: signed_at, max_age: max_age]

    token = sign(secret, salt, {channel_ref, app_id, user_id}, opts)

    "#{valid_until}:#{token}"
  end

  @type token_error_reason() ::
          :expired | :invalid | {:different_channel, channel_ref(), application(), user_ref()}
  @spec verify_token(channel_ref(), channel_secret()) ::
          {:ok, application(), user_ref()} | {:error, token_error_reason()}
  def verify_token(channel_ref, channel_secret) do
    case String.split(string, ":") do
      [_valid_until, token] ->
        verify_token_secret(channel_ref, token)

      [token] ->
        verify_token_secret(channel_ref, token)
    end
  end

  defp verify_token_secret(channel_ref, channel_secret) do
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
    end
  end

  defp get_secret_and_salt! do
    case get_env(:channel_sender_ex, :secret_base) do
      data = {_secret, _salt} -> data
      other -> raise "Secret base no properly configured for application: #{other}"
    end
  end

  defp max_age do
    RulesProvider.get(:max_age)
  rescue
    _ -> 900
  end
end
