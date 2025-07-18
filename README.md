# cloudogu/gop-helm

A Helm chart for [GOP](https://github.com/cloudogu/gitops-playground).

Create a job that starts the GOP pod, which in turns installs an IDP on your cluster.

Afterward, you could run helm uninstall. This would only uninstall the initial job, the IDPs stays where it is.

We recommend adding an application that allows for managing [GOP via GitOps](#managing-gop-via-gitops).
This allows for upgrading all cluster-resources managed by GOP or adding more features later via a single git commit.

## Simple local installation
```bash
VERSION='a712542'  
bash <(curl -s "https://raw.githubusercontent.com/cloudogu/gitops-playground/$VERSION/scripts/init-cluster.sh")

# Consider adding --version for determinism
helm upgrade -i gop oci://ghcr.io/cloudogu/gop-helm -n gop --create-namespace --set image.tag=$VERSION \
  --set extraArgs="{ --argocd, --ingress-nginx, --base-url=http://localhost}"

# Alternative: use heredoc. Advantage: config map stays in cluster for reference 
# Consider adding --version for determinism
helm upgrade gop -i oci://ghcr.io/cloudogu/gop-helm -n gop --create-namespace --values - <<EOF
image:
  tag: a712542
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

# Consider adding --version for determinism
helm upgrade gop -i oci://ghcr.io/cloudogu/gop-helm -n gop --create-namespace --values - <<EOF
image:
  tag: a712542
configSecret: gop
config:
  application:
    baseUrl: http://localhost
  features:
    argocd:
      active: true
    ingressNginx:
      active: true
configSecret: gop
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
      targetRevision: 0.1.0
      helm:
        valuesObject:
          # configSecret: gop
          image:
            tag: a712542
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
image:
  tag: a712542
# Uncomment if you are using a config secret  
# configSecret: gop
config:
  # yaml-language-server: $schema=https://raw.githubusercontent.com/cloudogu/gitops-playground/refs/heads/main/docs/configuration.schema.json
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
     targetRevision: 0.1.0
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

Make sure the `version` in Chart.yaml is set. Otherwise, the release job will fail.

On `main` branch:

```shell
TAG=0.2.0

git checkout main
[[ $? -eq 0 ]] && git pull
[[ $? -eq 0 ]] && git tag -s $TAG -m $TAG
[[ $? -eq 0 ]] && git push --follow-tags

[[ $? -eq 0 ]] && xdg-open https://ecosystem.cloudogu.com/jenkins/job/cloudogu-github/job/gop-helm/
```
