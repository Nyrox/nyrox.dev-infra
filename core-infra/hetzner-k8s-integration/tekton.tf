



data "http" "tekton-operator-crds" {
    url = "https://infra.tekton.dev/tekton-releases/operator/latest/release.yaml"
}

data "kubectl_file_documents" "tekton-operator-crds" {
    content = data.http.tekton-operator-crds.response_body
}

resource "kubectl_manifest" "tekton-operator-crds" {
    for_each = data.kubectl_file_documents.tekton-operator-crds.manifests
    yaml_body = each.value
}


data "http" "tekton-operator-profile-config" {
    url = "https://raw.githubusercontent.com/tektoncd/operator/main/config/crs/kubernetes/config/all/operator_v1alpha1_config_cr.yaml"
}

resource "kubectl_manifest" "tekton-operator-profile-config" {
    depends_on = [ kubectl_manifest.tekton-operator-crds ]
    yaml_body = data.http.tekton-operator-profile-config.response_body
}

// -- OAUTH Proxy

variable "tekton_dashboard_oauth_client_id" {
    sensitive = true
    type = string
}

variable "tekton_dashboard_oauth_client_secret" {
    sensitive = true
    type = string
}

resource "helm_release" "oauth2-proxy-tekton-dashboard" {
    name = "oauth2-proxy-tekton-dashboard"
    namespace = "tekton-aux"
    create_namespace = true
    repository = "https://oauth2-proxy.github.io/manifests"
    chart = "oauth2-proxy"
    wait = false

    values = [
<<EOT
config:
    clientID: ${var.tekton_dashboard_oauth_client_id}
    clientSecret: ${var.tekton_dashboard_oauth_client_secret}
    configFile: |
        upstreams = ["http://tekton-dashboard.tekton-pipelines:9097"]
        email_domains = [ "nyrox.dev" ]
        cookie_domains = [ ".nyrox.dev" ]
        whitelist_domains = [ ".nyrox.dev" ]

extraArgs:
    provider: github
    redirect-url: "https://tekton.nyrox.dev/oauth2/callback"
    login-url: "https://git.nyrox.dev/login/oauth/authorize"
    redeem-url: "https://git.nyrox.dev/login/oauth/access_token"
    validate-url: "https://git.nyrox.dev/api/v1/user/emails"
    provider-display-name: Nyrox Git Forge
    reverse-proxy: true

gatewayApi:
    enabled: true
    gatewayRef:
        name: main-gateway
        namespace: nginx-gateway
    hostnames:
        - tekton.nyrox.dev
EOT
    ]
}
