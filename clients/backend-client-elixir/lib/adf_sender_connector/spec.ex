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

      @args_definition [
        sender_url: [
          type: :string,
          required: true
        ],
        http_opts: [
          type: :keyword_list,
          required: false
        ],
        name: [
          type: :string,
          required: true
        ],
        app_ref: [
          type: :string,
          required: false
        ],
        user_ref: [
          type: :string,
          required: false
        ]
      ]

      @type application_ref() :: String.t()
      @type user_ref() :: String.t()
      @type channel_ref() :: String.t()
      @type message_id() :: String.t()
      @type correlation_id() :: String.t()
      @type event_name() :: String.t()
      @type message_data() :: iodata()

      # inherit server
      use GenServer

      @doc false
      def start_link(args, opts \\ []) do
        {:sender_url, url} = args
        new_opts = [sender_url: url] ++ opts
        GenServer.start_link(__MODULE__, new_opts, name: via_tuple(Keyword.fetch!(new_opts, :name)))
      end

      @doc false
      def init(args) do
        {:ok, args}
      end

      def child_spec(args) do
        %{
          id: __MODULE__,
          start: {__MODULE__, :start_link, [args]},
        }
      end

      defp via_tuple(process_alias) do
       {:via, Registry, {Registry.ADFSenderConnector, process_alias}}
      end

      # allow overriding of init
      defoverridable [init: 1, child_spec: 1]

      #################
      # Configuration #
      #################

      @doc false
      defp decode_response({:ok, adf_result} = _response) do
        case adf_result.status_code do
          x when x in [200, 202] ->
            {:ok,
              adf_result
              |> Map.get(:body)
              |> Jason.decode!()
              # |> Enum.map(fn {key, val} -> {String.to_atom(key), val} end)
              # |> Enum.into(%{})
            }

          400 ->

            Logger.error("Channel Sender returned status 400: #{inspect(adf_result)}")
            {:error, :channel_sender_bad_request}

          _ ->

            Logger.error("Channel Sender unknown error: #{inspect(adf_result)}")
            {:error, :channel_sender_unknown_error}
        end
      end

      @doc false
      defp decode_response({:error, http_error} = _response) do
        Logger.error("Channel Sender returned error: #{inspect(http_error)}")

        case http_error.reason do
          :econnrefused ->
            {:error, :channel_sender_econnrefused}

          _ ->
            {:error, :channel_sender_unknown_error}
        end
      end

      defp parse_http_opts(opts) do
        case Keyword.fetch(opts, :http_opts) do
          {:ok, http_opts} ->
            http_opts
          :error ->
            [timeout: 7_000, recv_timeout: 7_000, max_connections: 2000]
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
