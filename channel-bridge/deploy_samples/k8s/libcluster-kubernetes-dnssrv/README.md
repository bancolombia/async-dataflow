# K8S Templates and libcluster strategy Cluster.Strategy.Kubernetes.DNSSRV

## Erlang cluster configuration

Building an Erlang Cluster with `libcluster` strategy named:  [`Cluster.Strategy.Kubernetes.DNSSRV`](https://hexdocs.pm/libcluster/Cluster.Strategy.Kubernetes.DNSSRV.html). You'll need:

- A headless service: This is a kubernetes service without an IP address. This one instead returns pod IP, allowing pods to comunicate each other. See service named `adfbridge-headless` in [app.yaml](./app.yaml).

- A Statefulset: in which pods mantain network identity.

**NOTE**: Unlike strategy `Cluster.Strategy.Kubernetes`, a service-account it is not required.

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
        ## Rabbitmq host and credentials can be configured with an AWS Secret, indicating the secret name.
        ## The secret must be a valid Json containing the following keys: "virtualhost", "hostname", "username",
        ## "password", "port". For example:
        ##
        ## { "username": <user name>, "password": <pw>, "hostname": <host>, "port": <port>, "virtualhost": <vhost>, "ssl": <true/false>}
        ##
        # secret: rabbitmq-secret

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
        
      # sqs:
      #   queue: sample-queue
      #   ## producer and processor concurrency
      #   producer_concurrency: 1
      #   producer_prefetch: 2
      #   processor_concurrency: 2
      #   processor_max_demand: 1

    topology:
      strategy: Elixir.Cluster.Strategy.Kubernetes.DNSSRV
      config: 
        service: "adfbridge-headless"
        application_name: "channel_bridge_ex"
        namespace: "bridgenm"
        polling_interval: 5000

  sender:
    url: http://adfsender.sendernm.svc.cluster.local:8081

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

- `service` it's the headless service name defined in `app.yaml`.
- `application_name` it's the elixir release name. See `mix.exs`. Default release name is `channel_bridge_ex`.
- `namespace`: namespace where bridge is being deployed.

b. **Define related env vars for release**

You must mount a file in the following path `/app/config/env.sh`, performing any env configuration:

```bash
export RELEASE_DISTRIBUTION=name
export RELEASE_NODE=channel_birdge_ex@(hostname -f)
```

This pair of files can be mounted as a volume and passed to the container. See `configmap.yaml` and volume mount definition in `app.yaml`.
