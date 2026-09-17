# cloudogu/gop-helm

A Helm chart for [GOP](https://github.com/cloudogu/gitops-playground).

Create a job that starts the GOP pod, which in turns installs an IDP on your cluster.

Afterward, you could run helm uninstall. This would only uninstall the initial job, the IDPs stays where it is.

We recommend adding an application that allows for managing [GOP via GitOps](#managing-gop-via-gitops).
This allows for upgrading all cluster-resources managed by GOP or adding more features later via a single git commit.

## GOP version and configuration

This chart pins the GOP image to version `0.19.0`. If `image.tag` is empty, the chart uses the pinned
`appVersion` from `Chart.yaml` as a fallback. Set `image.tag` only when you deliberately want to override
the GOP version shipped with this chart.

The complete GOP configuration is maintained in the GitOps Playground repository:

* [Configuration reference for GOP 0.19.0](https://github.com/cloudogu/gitops-playground/blob/0.19.0/docs/Configuration.md)
* [Configuration schema for GOP 0.19.0](https://raw.githubusercontent.com/cloudogu/gitops-playground/refs/tags/0.19.0/docs/configuration.schema.json)

Use the documentation matching the GOP image version. Configuration keys may change between GOP releases.

## Simple local installation

```bash
GOP_VERSION='0.19.0'
CHART_VERSION='0.4.2'
bash <(curl -s "https://raw.githubusercontent.com/cloudogu/gitops-playground/${GOP_VERSION}/scripts/init-cluster.sh")

# Pin the chart version for a reproducible installation.
helm upgrade -i gop oci://ghcr.io/cloudogu/gop-helm --version "${CHART_VERSION}" -n gop --create-namespace \
  --set extraArgs="{ --argocd, --ingress-nginx, --base-url=http://localhost}"

# Alternative: use heredoc. Advantage: config map stays in cluster for reference
helm upgrade gop -i oci://ghcr.io/cloudogu/gop-helm --version "${CHART_VERSION}" -n gop --create-namespace --values - <<EOF
config:
  application:
    baseUrl: http://localhost
  features:
    argocd:
      active: true
    ingressNginx:
      active: true
EOF
```

## Recommended: Use secret for passwords

We recommend configuring passwords via a secret.

```bash
kubectl apply -f - <<EOF
apiVersion: v1
kind: Namespace
metadata:
  name: gop
---
apiVersion: v1
kind: Secret
metadata:
  name: gop
  namespace: gop
type: Opaque
stringData:
  config.yaml: |
    application:
      password: "admin2"
EOF

helm upgrade gop -i oci://ghcr.io/cloudogu/gop-helm --version 0.4.2 -n gop --create-namespace --values - <<EOF
configSecret: gop
config:
  application:
    baseUrl: http://localhost
  features:
    argocd:
      active: true
    ingressNginx:
      active: true
EOF
```

# Managing GOP via GitOps

After the initial version is deployed, we recommend adding an application that allows for managing GOP via GitOps.

This allows for upgrading all cluster-resources managed by GOP or adding more features later via a single git commit.

## Simple example
Commit this Argo CD app to 

* Repo `argocd/cluster-resources`
* Path: `argocd`
* Filename: `gop.yaml`

e.g. via http://scmm.localhost/scm/repo/argocd/cluster-resources/code/sourceext/create/main/argocd

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: gop
  namespace: argocd
spec:
  destination:
    namespace: gop
    server: https://kubernetes.default.svc
  project: argocd
  sources:
    - repoURL: ghcr.io/cloudogu
      chart: gop-helm
      targetRevision: 0.4.2
      helm:
        valuesObject:
          # configSecret: gop
          extraArgs:
            - --argocd
            - --ingress-nginx
            - --base-url=http://localhost
  syncPolicy:
    automated:
      selfHeal: true
```

## Separate values.yaml / config

Create separate config in 
 * Repo `argocd/cluster-resources`, 
 * Path: `apps/gop`
 * Filename: `values.yaml`

e.g. via http://scmm.localhost/scm/repo/argocd/cluster-resources/code/sourceext/create/main/apps/gop

```yaml
# Uncomment if you are using a config secret  
# configSecret: gop
config:
  # yaml-language-server: $schema=https://raw.githubusercontent.com/cloudogu/gitops-playground/refs/tags/0.19.0/docs/configuration.schema.json
  application:
    baseUrl: http://localhost
  features:
    argocd:
      active: true
    ingressNginx:
      active: true
```

Then commit Argo CD app to 
 
* Repo `argocd/cluster-resources`
* Path: `argocd` 
* Filename: `gop.yaml`

e.g. via http://scmm.localhost/scm/repo/argocd/cluster-resources/code/sourceext/create/main/argocd

```yaml
apiVersion: argoproj.io/v1alpha1  
kind: Application  
metadata:  
  name: gop  
  namespace: argocd  
spec:  
  destination:
    namespace: gop
    server: https://kubernetes.default.svc  
  project: argocd
  sources:
   - repoURL: ghcr.io/cloudogu
     chart: gop-helm
     targetRevision: 0.4.2
     helm:
       valueFiles:
         - $clusterResources/apps/gop/values.yaml
   - repoURL: http://scmm.scm-manager.svc.cluster.local/scm/repo/argocd/cluster-resources
     path: apps/gop1
     targetRevision: main
     ref: clusterResources
  syncPolicy:  
    automated:  
      selfHeal: true
```

## Releasing

Before releasing the chart:

1. Set `version` in `Chart.yaml` to the new chart version.
2. Set `appVersion` in `Chart.yaml` and `image.tag` in `values.yaml` to the same released GOP version.
3. Update the version-specific GOP configuration and schema links in `README.md` and `values.yaml`.
4. Run `helm lint .` and `helm unittest .`.

Keeping `image.tag` and `appVersion` pinned prevents installations from unexpectedly using `latest`.
The chart release job requires the Git tag to match `version` from `Chart.yaml`.

On `main` branch:

```shell
TAG=0.4.2

git checkout main
[[ $? -eq 0 ]] && git pull
[[ $? -eq 0 ]] && git tag -s $TAG -m $TAG
[[ $? -eq 0 ]] && git push --follow-tags

[[ $? -eq 0 ]] && xdg-open https://ecosystem.cloudogu.com/jenkins/job/cloudogu-github/job/gop-helm/job/main/build?delay=0sec
```
