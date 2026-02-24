# Configuration

You need to setup channel sender configuration before start using it. The next sections will describe the configuration parameters and how to set them up.

The channel sender configuration is stored in a YAML file. By default, the configuration file is located at `/app/config/config.yaml`. This file has the following structure:

```yaml
channel_sender_ex:
  # port number for the REST API, defaults to 8081
  rest_port: 8081
  # port number for the socket/sse/longpoll connection, defaults to 8082
  socket_port: 8082
  secret_generator:
    # base string used for generating secret tokens. This should be a long and random string to ensure security.
    base: "aV4ZPOf7T7HX6GvbhwyBlDM8B9jfeiwi+9qkBnjXxUZXqAeTrehojWKHkV3U0kGc"
    # salt value used in the token generation process to add an extra layer of security. This should also be a long and random string.
    salt: "socket auth"
    # max time (in seconds) for a token to be valid, this parameter is also used to hold the channel genstatemachine in wainting state before it is closed, defaults to 900
    max_age: 900
  # initial time in milliseconds to wait before re-send a message not acked to a channel, defaults to 900
  initial_redelivery_time: 900
  # max time in milliseconds to wait the client to send the auth token before closing the channel, defaults to 30000
  socket_idle_timeout: 30000

  # specifies the maximum time (in milliseconds) that the Elixir supervisor waits 
  # for child channel processes to terminate after sending it an exit signal 
  # (:shutdown). This time is used by all gen_statem processes to perform clean up
  # operations before shutting down. Defaults to 10000
  channel_shutdown_tolerance: 10000

  # specifies the maximum drift time (in seconds) the channel process
  # will consider for emiting a new secret token before the current one expires.
  # Time to generate will be the greater value between (max_age / 2) and
  # (max_age - min_disconnection_tolerance) defaults to 50
  min_disconnection_tolerance: 50

  # max time in milliseconds to wait for a channel process to reply after sending a message, defaults to 2000
  on_connected_channel_reply_timeout: 2000

  # max time a channel process will wait to perform the send operation before times out, defaults to 1000
  accept_channel_reply_timeout: 1000

  # Allowed max number of unacknowledged messages per client connection
  # after this limit is reached, oldes unacknowledged messages will be dropped, defaults to 100
  max_unacknowledged_queue: 100

  # Allowed max number of retries to re-send unack'ed message to a channel, defaults to 20
  max_unacknowledged_retries: 20
  
  # Allowed max number of messages pending to be sent to a channel
  # received by sender while on waiting state (no socket connection), defaults to 100
  max_pending_queue: 100

  # channel_shutdown_socket_disconnect: Defines the waiting time of the channel process
  # after a socket disconnection, in case the client re-connects. The disconection can be
  # clean or unclean. The channel process will wait for the client to re-connect before
  #
  # on_clean_close: time in seconds to wait before shutting down the channel process when a 
  # client explicitlly ends the socket connection (clean close). A value of 0, will
  # terminate the channel process immediately. This value should never be greater than max_age. defaults to 30
  #
  # on_disconnection: time in seconds to wait before shutting down the channel process when the
  # connectin between the client and server accidentally or unintendedlly is interrupted. 
  # A value of 0, will terminate the channel process immediately. This value should never 
  # be greater than max_age. defaults to 300
  channel_shutdown_socket_disconnect: 
    on_clean_close: 30
    on_disconnection: 300

  cowboy:
    # https://ninenines.eu/docs/en/cowboy/2.12/manual/cowboy_http/
    protocol_options:
      active_n: 4000 # defaults to 1000
      max_keepalive: 15000 # defaults to 5000
      request_timeout: 10000 # defaults to 10000
      idle_timeout: 120000
    # https://ninenines.eu/docs/en/ranch/1.7/manual/ranch/
    transport_options:
      num_acceptors: 1000 # defaults to 200
      max_connections: :infinity # defaults to 16384

  no_start: false
  topology:
    strategy: Elixir.Cluster.Strategy.Gossip # for local development

    # strategy: Elixir.Cluster.Strategy.Kubernetes # topology for kubernetes
    # config: 
    #   mode: :hostname
    #   kubernetes_ip_lookup_mode: :pods
    #   kubernetes_service_name: "adfsender-headless"
    #   kubernetes_node_basename: "channel_sender_ex"
    #   kubernetes_selector: "cluster=beam"
    #   namespace: "sendernm"
    #   polling_interval: 5000

    # see https://github.com/bancolombia/async-dataflow/tree/master/channel-sender/deploy_samples/k8s
    # for more information about the kubernetes configuration with libcluser
  opentelemetry:
    traces_enable: true # default to false
    traces_endpoint: "http://localhost:4318"
    traces_ignore_routes: ["/health", "/metrics"]
  metrics:
    enabled: true # default to false
    prometheus_port: 9568 # defaults to 9568
    active_interval_minutes_count: 2
logger:
  level: debug
```