# K8S Templates and libcluster strategy Cluster.Strategy.Kubernetes

## Erlang cluster configuration

Building an Erlang Cluster with `libcluster` strategy named:  [`Cluster.Strategy.Kubernetes`](https://hexdocs.pm/libcluster/Cluster.Strategy.Kubernetes.html). You'll need:

- A headless service: This is a kubernetes service without an IP address. This one instead returns pod IP, allowing pods to comunicate each other. See service named `adfbridge-headless` in [app.yaml](./app.yaml).

- A service-account that allows listing endpoints / pods: this is necesary in this strategy due the need to know available pods in the statefulset. See [roles.yaml](./roles.yaml). 

  *IMPORTANT*: If using a service-account its not allowed or desired check the other two supported strategies in `libcluster`: Cluster.Strategy.Kubernetes.DNS or Cluster.Strategy.Kubernetes.DNSSRV

### 2.1. ADF Bridge configuration

a. **Basic Bridge Configuration**

You can provide all bridge configuration via a yaml file. 

For containers using prod release, path should be: `/app/config/config.yaml` for mounting the file.

config.yaml:
```yaml
bridge:
  port: 8080
  cloud_event_channel_identifier:
    - $.subject
  request_channel_identifier:
    - "$.req_headers['sub']"
  cloud_event_mutator: Elixir.BridgeCore.CloudEvent.Mutator.DefaultMutator
  channel_authenticator: Elixir.BridgeRestapiAuth.PassthroughProvider
  event_bus:
    rabbitmq:
      bindings:
        - name: domainEvents
          routing_key:
            - business.#
      queue: adf_bridge_ex_queue
      
      ##
      ## Optionally and for local dev environments  Rabbitmq host and credentials can be configured directly 
      ## here:
      username: <your user>
      password: <your pw>
      hostname: localhost
      port: 5672
      virtualhost: /
      ssl: false

      ## producer and processor concurrency
      producer_concurrency: 1
      producer_prefetch: 2
      processor_concurrency: 2
      processor_max_demand: 1
      
  topology:
    strategy: Elixir.Cluster.Strategy.Gossip

sender:
  url: http://sender.sendernm:8081

aws:
  region: us-east-1
  ## creds for local dev::
  creds:
    access_key_id:
      - SYSTEM:AWS_ACCESS_KEY_ID
      # - instance_role
    secret_access_key:
      - SYSTEM:AWS_SECRET_ACCESS_KEY
      # - instance_role
  ## secretsmanager local endpoint configuration for local dev:
  # secretsmanager:
  #   scheme: http://
  #   host: localhost
  #   region: us-east-1
  #   port: 4566
  debug_requests: true

logger:
  level: debug
```

Note the specifics in the libcluster configuration:

- `kubernetes_service_name` it's the name of the headless-service defined in app.yaml.
- `kubernetes_node_basename` it's the elixir release name. See `mix.exs`. Default release name is `channel_bridge_ex`.
- `kubernetes_selector` The selector tag to search for in app.yaml.
- `namespace`: namespace where bridge is being deployed.

b. **Define related env vars for release**

You must mount a file in the following path `/app/config/env.sh`, performing any env configuration:

```bash
export RELEASE_DISTRIBUTION=name
export RELEASE_NODE=channel_bridge_ex@${POD_NAME}.${POD_NAME_DNS}
```

check env vars POD_NAME and POD_NAME_DNS in app.yaml.

This will form a node name like: `channel_bridge_ex@bridge-0.adfbridge-headless.bridgenm.svc.cluster.local`

This pair of files can be mounted as a volume and passed to the container. See `configmap.yaml` and volume mount definition in `app.yaml`.
