# K8S Templates and libcluster strategy Cluster.Strategy.Kubernetes

## Istio Gateway and VirtualService configuration

Gateway:

```yaml
apiVersion: networking.istio.io/v1alpha3
kind: Gateway
metadata:
  name: adfsender-gw
  namespace: sendernm
spec:
  selector:
    istio: ingressgateway 
  servers:
    - port:
        name: secure-port
        number: 443
        protocol: HTTPS
      tls:
        ## this is a cert and key created as a secret in istio-system namespace
        mode: SIMPLE
        credentialName: adfsender-credential
      hosts:
        - adfsender.example.com
```

VirtualService, exposing websocket port:

```yaml
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: adfsender-vs-socket
  namespace: sendernm
spec:
  hosts:
    - adfsender.example.com
  gateways:
    - adfsender-gw
  http:
    - match:
        - uri:
            prefix: /ext/socket
      rewrite:
        uri: /ext/socket
      route:
        - destination:
            host: adfsender
            port:
              number: 8082
```

VirtualService, exposing rest endpoints:


```yaml
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: adfsender-vs-rest
  namespace: sendernm
spec:
  hosts:
    - adfsender.example.com
  gateways:
    - adfsender-gw
  http:
    - match:
        - uri:
            prefix: /ext/socket
      rewrite:
        uri: /ext/socket
      route:
        - destination:
            host: adfsender
            port:
              number: 8082
```

VirtualService por EPMD port:

  ```yaml
  apiVersion: networking.istio.io/v1alpha3
  kind: VirtualService
  metadata:
    name: adfsender-vs-epmd
    namespace: sendernm
  spec:
    hosts:
    - adfsender-headless
    tcp:
    - match:
      - port: 4369
      route:
      - destination:
          host: adfsender-headless
          port:
            number: 4369   
  ```

## Erlang cluster configuration

Building an Erlang Cluster with `libcluster` strategy named:  [`Cluster.Strategy.Kubernetes`](https://hexdocs.pm/libcluster/Cluster.Strategy.Kubernetes.html). You'll need:

- A headless service: This is a kubernetes service without an IP address. This one instead returns pod IP, allowing pods to comunicate each other. See service named `adfsender-headless` in [app.yaml](./app.yaml).

- A service-account that allows listing endpoints / pods: this is necesary in this strategy due the need to know available pods in the statefulset. See [roles.yaml](./roles.yaml). 

  *IMPORTANT*: If using a service-account its not allowed or desired check the other two supported strategies in `libcluster`: Cluster.Strategy.Kubernetes.DNS or Cluster.Strategy.Kubernetes.DNSSRV

### 2.1. ADF Sender configuration

a. **Topology config**

You can set topology related configuration in `config\runtime.exs`:

```elixir
import Config

config :logger, level: :info

config :channel_sender_ex,
  secret_base:
    {"aV4ZPOf7T7HX6GvbhwyBlDM8B9jfeiwi+9qkBnjXxUZXqAeTrehojWKHkV3U0kGc", "socket auth"},
  socket_port: 8082,
  initial_redelivery_time: 900,
  socket_idle_timeout: 30000,
  rest_port: 8081,
  max_age: 900,
  topology: [
    strategy: Elixir.Cluster.Strategy.Kubernetes,
        config: [
            mode: :hostname
            kubernetes_ip_lookup_mode: :pods
            kubernetes_service_name: "adfsender-headless"
            kubernetes_node_basename: "channel_sender_ex"
            kubernetes_selector: "cluster=beam"
            namespace: "sendernm"
            polling_interval: 5000
        ]
    ]
```
where:

- `kubernetes_service_name` it's the name of the headless-service defined in app.yaml.
- `kubernetes_node_basename` it's the elixir release name. See `mix.exs`. Default release name is `channel_sender_ex`.
- `kubernetes_selector` The selector tag to search for in app.yaml.
- `namespace`: namespace where sender is being deployed.

b. **Define related env vars for release**

via `rel/env.sh.eex` file:

```elixir
export RELEASE_DISTRIBUTION=name
export RELEASE_NODE=<%= @release.name %>@${POD_NAME}.${POD_NAME_DNS}
```

check env vars POD_NAME and POD_NAME_DNS in app.yaml.

This will form a node name like: `channel_sender_ex@sender-0.adfsender-headless.sendernm.svc.cluster.local`

This pair of files can be mounted as a volume and passed to the container. See `configmap.yaml` and volume mount definition in `app.yaml`.
