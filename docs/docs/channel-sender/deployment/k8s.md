# Kubernetes (k8s)

At [deploy_samples/k8s](https://github.com/bancolombia/async-dataflow/tree/master/channel-sender/deploy_samples/k8s) you can find deploy samples for kubernetes, using different strategies to connect nodes in erlang cluster.

### Connect nodes in erlang cluster in k8s

ADF Sender incorporate `libcluster` dependency in order to facilitate the automatic configuration of erlang clusters in kubernetes.

We have included manifests to deploy ADF sender on kubernetes (and also if istio is present), using 3 of the strategies supported by `libcluster`.

- [libcluster-kubernetes-dns](https://github.com/bancolombia/async-dataflow/tree/master/channel-sender/deploy_samples/k8s/libcluster-kubernetes-dns)
- [libcluster-kubernetes-dnssrv](https://github.com/bancolombia/async-dataflow/tree/master/channel-sender/deploy_samples/k8s/libcluster-kubernetes-dnssrv)
- [libcluster-kubernetes](https://github.com/bancolombia/async-dataflow/tree/master/channel-sender/deploy_samples/k8s/libcluster-kubernetes)

Configuration is defined in a configmap which is mounted as a volume in the deployment, so you can change the configuration without the need to build a new image. You can find the configuration in `configmap.yaml` file, and the deployment manifest in `app.yaml` file. This templates has istio ingress manifests that can see in `gateway.yaml` 