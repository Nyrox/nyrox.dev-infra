

# Steps for first-time setup

`terraform apply -var-file=../.tfvars -target=module.hetzner-vms`

>Update fetch-k3s-config.sh script

`../fetch-k3s-config.sh`

>Update ~/.kube/config to use public k8s control plane IP

`terraform apply -var-file=../.tfvars -target=module.hetzner-k8s.helm_release.hetzner-cloud-controller`

`cilium install --version 1.18.4 --set=ipam.operator.clusterPoolIPv4PodCIDRList="10.42.0.0/16"`

`kubectl apply --server-side -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.4.1/standard-install.yaml`
`kubectl kustomize "https://github.com/nginx/nginx-gateway-fabric/config/crd/gateway-api/standard?ref=v2.2.1" | kubectl apply -f -`

`terraform apply -var-file=../.tfvars -target=module.hetzner-k8s.helm_release.cert-manager`
`terraform apply -var-file=../.tfvars`