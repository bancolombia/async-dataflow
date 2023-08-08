# K8S Templates

This folder contains templates to deploy channel sender in a kubernetes environment and specific configurations to build an erlang cluster with several nodes.

## Libcluster for cluster erlang configuration

The demo templates rely on [libcluster](https://hexdocs.pm/libcluster/readme.html), which is a dependency used in Sender to configure the Erlang cluster.

## Istio

These templates also asume istio is installed and enforcing mtls cluster-wide.

## Strategies

a. [libcluster-kubernetes](./libcluster-kubernetes/README.md): Templates for deploying sender using  `libcluster` strategy `Cluster.Strategy.Kubernetes`.

b. [libcluster-kubernetes-dns](./libcluster-kubernetes-dns/README.md): Similar to (A), but using the `Cluster.Strategy.Kubernetes.DNS` strategy.

c. [libcluster-kubernetes-dnssrv](./libcluster-kubernetes-dnssrv/README.md): Similar to (A) but using the 
 `Cluster.Strategy.Kubernetes.DNSSRV` strategy. 
