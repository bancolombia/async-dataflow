import Config

if (config_env() == :prod) do
  config :channel_sender_ex,
  secret_base:
  {"aV4ZPOf7T7HX6GvbhwyBlDM8B9jfeiwi+9qkBnjXxUZXqAeTrehojWKHkV3U0kGc", "socket auth"},
  socket_port: 8082,
  initial_redelivery_time: 900,
  socket_idle_timeout: 30000,
  rest_port: 8081,
  max_age: 900,
  topology: [
    strategy: Cluster.Strategy.Kubernetes,
      config: [
        mode: :hostname,
        kubernetes_ip_lookup_mode: :pods,
        kubernetes_service_name: "adfsender-headless",
        kubernetes_node_basename: "channel_sender_ex",
        kubernetes_selector: "cluster=beam",
        namespace: "sendernm",
        polling_interval: 5000
      ]
  ]
end
