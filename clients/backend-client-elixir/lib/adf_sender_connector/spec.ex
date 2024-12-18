defmodule AdfSenderConnector.Spec do
  @moduledoc """
  Provides base implementation for connector modules.
  """

  @doc false
  defmacro __using__(opts) do
    option = case Keyword.fetch(opts, :option) do
      {:ok, op} -> op
      _ -> :ok
    end
    # quote  do
    quote location: :keep do
      @__option__ unquote(option)
      @after_compile unquote(__MODULE__)

      require Logger

      @default_local "http://localhost:8081"

      @type application_ref() :: binary()
      @type user_ref() :: binary()
      @type channel_ref() :: binary()
      @type message_id() :: binary()
      @type correlation_id() :: binary()
      @type event_name() :: binary()
      @type message_data() :: iodata()

      #################
      # Configuration #
      #################
      def send_request(body, sender_url) do
        base_url = Application.get_env(:adf_sender_connector, :base_path, @default_local)

        response = Finch.build(:post, base_url <> sender_url, headers(), body)
          |> Finch.request(SenderHttpClient)

        case response do
          {:ok, %Finch.Response{status: status, body: response_body}} ->
            {status, response_body}
          {:error, %Mint.TransportError{reason: reason} = detail} ->
            Logger.error("ADF Sender Client - Error sending request: #{inspect(detail)}")
            {:error, reason}
        end
      end

      defp headers do
        [{"content-type", "application/json"}]
      end

      @doc false
      def decode_response({status_code, body} = _response) do
        case status_code do
          x when x in [200, 202] ->
            {:ok,
            body
            |> Jason.decode!()}

          400 ->

            Logger.error("ADF Sender Client - received status 400: #{inspect(body)}")
            {:error, :channel_sender_bad_request}

          _ ->

            Logger.error("ADF Sender Client - unknown error: #{inspect(body)}")
            {:error, :channel_sender_unknown_error}
        end
      end

      # config overrides
      defoverridable [
        decode_response: 1,
      ]

    end
  end

  def __after_compile__(env, _bytecode) do
    _option = Module.get_attribute(env.module, :__option__)
    # validate option
    # maybe raise exception, assert_raise in test
    # when option is a capture, run it.
  end
end
