defmodule ChannelSenderEx.Model.CreateChannelData do
  @moduledoc """
  This module contains the data structure for creating a channel.
  """
  defstruct [
    :application,
    :user_ref,
    :meta
  ]

  @type application :: String.t()
  @type user_ref :: String.t()
  @type external_ref :: String.t()
  @type meta :: map()

  @spec validate(map()) :: {:ok, application, user_ref, external_ref}
  def validate(%{"application_ref" => application_ref, "user_ref" => user_ref, "external_ref" => external_ref})
      when is_binary(application_ref) and
             application_ref != "" and
             is_binary(user_ref) and
             user_ref != "" and
             is_binary(external_ref) and
             external_ref != "" do
    {:ok, application_ref, user_ref, external_ref}
  end

  @spec validate(map()) :: {:ok, application, user_ref, external_ref}
  def validate(%{"application_ref" => application_ref, "user_ref" => user_ref})
      when is_binary(application_ref) and
             application_ref != "" and
             is_binary(user_ref) and
             user_ref != "" do
    {:ok, application_ref, user_ref, nil}
  end

  def validate(_), do: {:error, :invalid_data}

  def from(_, _), do: {:error, :invalid_data}
end
