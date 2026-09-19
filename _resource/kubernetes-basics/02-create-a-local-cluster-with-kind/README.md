# Kubernetes Basics Chapter 2 Resource

`kind-config.yaml` creates a local Kind cluster named `kubernetes-basics` when used with the
following command:

```sh
kind create cluster --name kubernetes-basics --config kind-config.yaml
```

The configuration creates one control-plane node and one worker node. It intentionally has no
host-port mappings because the Chapter 1 Deployment is not exposed outside the cluster.

## Verify the cluster

```sh
kubectl config current-context
kubectl get nodes -o wide
kind get clusters
```

The current context should be `kind-kubernetes-basics`, and both nodes should become `Ready`.

## Apply the Chapter 1 resource

```sh
kubectl apply -f ../01-what-is-kubernetes/hello-web-deployment.yaml
kubectl rollout status deployment/hello-web
kubectl get pods -l app=hello-web -o wide
```

## Clean up

```sh
kind delete cluster --name kubernetes-basics
```

## Validate the configuration without creating a cluster

```sh
ruby -e 'require "yaml"; YAML.load_file("kind-config.yaml"); puts "YAML parse: OK"'
kind create cluster --help | grep -- --config
```

The first command checks YAML syntax. The second confirms that the installed Kind command accepts
the `--config` option. Kind validates its full configuration schema while creating a cluster, so
there is no portable Kind-only dry run for this file.