# K8S Templates and libcluster strategy Cluster.Strategy.Kubernetes.DNSSRV

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

Building an Erlang Cluster with `libcluster` strategy named:  [`Cluster.Strategy.Kubernetes.DNSSRV`](https://hexdocs.pm/libcluster/Cluster.Strategy.Kubernetes.DNSSRV.html). You'll need:

- A headless service: This is a kubernetes service without an IP address. This one instead returns pod IP, allowing pods to comunicate each other. See service named `adfsender-headless` in [app.yaml](./app.yaml).

- This requires a Statefulset: in which pods mantain network identity.

**NOTE**: Unlike strategy `Cluster.Strategy.Kubernetes`, a service-account it is not required.

### 2.1. ADF Sender configuration

a. **Basic Sender Configuration**

You can provide all sender configuration via a yaml file. 

For containers using prod release, path should be: `/app/config/config.yaml` for mounting the file.

config.yaml:
```yaml
channel_sender_ex:
  rest_port: 8081
  socket_port: 8082
  secret_generator:
    base: "aV4ZPOf7T7HX6GvbhwyBlDM8B9jfeiwi+9qkBnjXxUZXqAeTrehojWKHkV3U0kGc"
    salt: "socket auth"
    max_age: 900
  initial_redelivery_time: 900
  socket_idle_timeout: 30000
  channel_shutdown_tolerance: 10000
  min_disconnection_tolerance: 50
  on_connected_channel_reply_timeout: 2000
  accept_channel_reply_timeout: 1000
  no_start: false
  # --- libcluster related config ---
  topology:
    strategy: Elixir.Cluster.Strategy.Kubernetes.DNSSRV
    config: 
      service: "adfsender-headless"
      application_name: "channel_sender_ex"
      namespace: "sendernm"
      polling_interval: 5000
  # --- end libcluster configuration ---

logger:
  level: debug
```

Note the specifics in the libcluster configuration:

- `service` it's the headless service name defined in `app.yaml`.
- `application_name` it's the elixir release name. See `mix.exs`. Default release name is `channel_sender_ex`.
- `namespace`: namespace where sender is being deployed.

b. **Define related env vars for release**

You must mount a file in the following path `/app/config/env.sh`, performing any env configuration:

```bash
export RELEASE_DISTRIBUTION=name
export RELEASE_NODE=channel_sender_ex@(hostname -f)
```

This pair of files can be mounted as a volume and passed to the container. See `configmap.yaml` and volume mount definition in `app.yaml`.
