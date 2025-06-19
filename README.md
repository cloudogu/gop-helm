# cloudogu/gop-helmm

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
 helm upgrade gop -i oci://ghcr.io/cloudogu/gop-helm -n gop --create-namespace --values - <<EOF | yaml
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
kubectl apply -f - <<EOF | yaml
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
helm upgrade gop -i oci://ghcr.io/cloudogu/gop-helm -n gop --create-namespace --values - <<EOF | yaml
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
configSecret: gop
EOF
```