# K8S Templates

This folder contains templates to deploy channel streams in a kubernetes environment and specific configurations to build an erlang cluster with several nodes.

## Libcluster for cluster erlang configuration

The demo templates rely on [libcluster](https://hexdocs.pm/libcluster/readme.html), which is a dependency used in Sender to configure the Erlang cluster.

## Istio

These templates also asume istio is installed and enforcing mtls cluster-wide.

## Strategies

a. [libcluster-kubernetes](./libcluster-kubernetes/README.md): Templates for deploying channel-streams using  `libcluster` strategy `Cluster.Strategy.Kubernetes`.

b. [libcluster-kubernetes-dns](./libcluster-kubernetes-dns/README.md): Similar to (A), but using the `Cluster.Strategy.Kubernetes.DNS` strategy.

c. [libcluster-kubernetes-dnssrv](./libcluster-kubernetes-dnssrv/README.md): Similar to (A) but using the 
 `Cluster.Strategy.Kubernetes.DNSSRV` strategy. 



## Who to deploy channel streams demo

1. Deploy a channel sender instance
2. Deploy rabbit mq. See demo deployment [rabbitmq/rabbitmq_sample.yaml](../rabbitmq/rabbitmq_sample.yaml)
3. Select one of the above strategies and apply all namespace, configmap, app and gateway manifests.

   Note: update host names of channel-sender and rabbit in `configmap.yaml` accordingly.

