defmodule ChannelSenderEx.Transport.TransportSpec do
  @moduledoc """
  Provides base implementation for transport modules.
  """

  @doc false
  defmacro __using__(opts) do
    option = case Keyword.fetch(opts, :option) do
      {:ok, op} -> op
      _ -> :none
    end

    # quote  do
    quote location: :keep do
      @__option__ unquote(option)
      @after_compile unquote(__MODULE__)

      import ChannelSenderEx.Core.Retry.ExponentialBackoff, only: [execute: 6]
      alias ChannelSenderEx.Core.ChannelSupervisor
      alias ChannelSenderEx.Core.RulesProvider

      require Logger

      @channel_key "channel"
      @channel_secret "authorization"

      ## ---------------------
      ## Non-Retryable errors
      ## ---------------------

      # Error code to indicate a generic bad request.
      @invalid_request_code "3006"

      # Error to indicate the shared secret for the channel is invalid
      @invalid_secret_code "3008"

      # Error code to indicate that the channel is already connected
      # and a new socket process is trying to connect to it.
      @socket_replaced "3009"

      ## -----------------
      ## Retryable errors
      ## -----------------

      # Error code to indicate bad request, specifically when
      # not providing a valid channel reference, or when clustered
      # the reference its yet visible among all replicas.
      # This error code and up, may be retried by the client.
      @invalid_channel_code "3050"

      ## -----------------
      ## Other codes
      ## -----------------
      @normal_close_code "3000"

      ## -----------------
      ## Types
      ## -----------------
      @type channel_ref() :: String.t()
      @type application_ref() :: String.t()
      @type user_ref() :: String.t()
      @type ch_ref() :: reference()
      @type pending_bag() :: %{String.t() => {pid(), reference()}}
      @type context_data() :: {application_ref(), user_ref(), ch_ref()}
      @type protocol_encoder() :: atom()

      def get_channel_from_qs(req) do
        # extracts the channel key from the request query string
        case :lists.keyfind(@channel_key, 1, :cowboy_req.parse_qs(req)) do
          {@channel_key, channel} = resp when byte_size(channel) > 10 ->
            print_socket_info(req, channel)
            resp
          _ ->
            {:error, @invalid_request_code}
        end
      end

      def get_token_from_header(req) do
        case Map.get(:cowboy_req.headers(req), "authorization") do
          nil ->
            {:error, @invalid_secret_code}

          "" ->
            {:error, @invalid_secret_code}

          value ->
            token = List.last(String.split(value))
            if token in [nil, ""] do
              {:error, @invalid_secret_code}
            else
              {@channel_secret, token}
            end
        end
      end

      def lookup_channel_addr(e = {:error, _desc}) do
        e
      end

      def lookup_channel_addr(channel_ref) do
        action_fn = fn _ -> check_channel_registered(channel_ref) end
        # retries 3 times the lookup of the channel reference (useful when running as a cluster with several nodes)
        # with a backoff strategy of 100ms initial delay and max of 500ms delay.
        execute(100, 500, 3, action_fn, fn ->
          Logger.error("Transport #{@__option__} unable to start. channel_ref process does not exist yet, ref: #{inspect(channel_ref)}")
          {:error, <<@invalid_channel_code>>}
        end, "lookup_channel_#{channel_ref}")
      end

      def check_channel_registered(channel_ref) do
        case ChannelSupervisor.whereis_channel(channel_ref) do
          :undefined ->
            :retry
          pid when is_pid(pid) ->
            {:ok, pid}
        end
      end

      def notify_connected(channel, kind) when is_binary(channel) do
        socket_event_bus = get_param(:socket_event_bus, ChannelSenderEx.Core.PubSub.SocketEventBus)
        ch_pid = socket_event_bus.notify_event({:connected, channel, kind}, self())
        Process.monitor(ch_pid)
      end

      def notify_connected(channel_pid, kind) when is_pid(channel_pid) do
        socket_event_bus = get_param(:socket_event_bus, ChannelSenderEx.Core.PubSub.SocketEventBus)
        socket_event_bus.notify_event({:connected, channel_pid, kind}, self())
        Process.monitor(channel_pid)
      end

      def get_param(param, def) do
        RulesProvider.get(param)
      rescue
        _e -> def
      end

      defp print_socket_info(req, channel) do
        case get_kind(req) do
          {:websocket, socket_id} ->
            Logger.debug("Socket #{socket_id} connecting to channel #{channel}")

          {:sse, _} ->
            Logger.debug("SSE connecting to channel #{channel}")

          {:longpoll, _} ->
            Logger.debug("LongPoll connecting to channel #{channel}")

          {:undefined, _} ->
            Logger.debug("Undefined transport connecting to channel #{channel}")
        end
      end

      defp get_kind(req) do
        case Map.get(req.headers, "sec-websocket-key", :undefined) do
          :undefined ->
            path = Map.get(req, :path, "")
            cond do
              String.contains?(path, "longpoll") ->
                {:longpoll, "longpoll"}
              String.contains?(path, "sse") ->
                {:sse, "sse"}
              true ->
                {:undefined, "undefined"}
            end

          socket_id -> {:websocket, socket_id}
        end
      end

    end
  end

  def __after_compile__(env, _bytecode) do
    _option = Module.get_attribute(env.module, :__option__)
    # validate option
    # maybe raise exception, assert_raise in test
    # when option is a capture, run it.
  end
end
