contour_release:="v1.29.1"
scripts:="test"/"scripts"
helm:="helm"

skipGatewayApi:="true"
skipCRDs:="false"

helmSkipCRDS:="--skip-crds"

helmNamespaceReleaseChartStanza:="--namespace projectcontour contour charts/contour"

export CLUSTERNAME:="contourgatewayapi"
export CERT_MANAGER_VERSION:="v1.15.1"
export INGRESS_HOST:="localhost" #TODOD
@info:
    echo "contour_release={{contour_release}}"
    echo "CLUSTERNAME: ${CLUSTERNAME:-## NOT SET ##}"
    echo "SKIP_GATEWAY_API_INSTALL: ${SKIP_GATEWAY_API_INSTALL:-## NOT SET ##}"
    echo "SKIP_CRD_INSTALL: ${SKIP_CRD_INSTALL:-## NOT SET ##}"



clean:
    {{scripts}}/cleanup.sh
    rm -rf target/

make-kind-cluster:
     SKIP_GATEWAY_API_INSTALL={{ skipGatewayApi }} SKIP_CRD_INSTALL={{ skipCRDs }} {{scripts}}/make-kind-cluster.sh
     #SKIP_GATEWAY_API_INSTALL={{ skipGatewayApi }} SKIP_CRD_INSTALL{{scripts}}/make-kind-cluster.sh

install-contour-script:
     {{scripts}}/install-contour-release.sh {{contour_release}}

template:
    {{helm}} template {{ helmSkipCRDS }} {{ helmNamespaceReleaseChartStanza }} --output-dir target/templated

install: template
    {{helm}} upgrade {{ helmSkipCRDS }} --create-namespace --install {{ helmNamespaceReleaseChartStanza }}

dependency-build:
    {{helm}} dependency build --namespace projectcontour charts/contour

dependency-update:
    {{helm}} dependency update --namespace projectcontour charts/contour

loadbalancerServiceName:="contour-envoy" # if gw-provisioner: envoy-contour !!
test-http:
    #!/usr/bin/env bash
    set -euo pipefail

    INGRESS_HOST=$( kubectl get svc -n projectcontour envoy-contour -o json | jq -r '.status.loadBalancer.ingress[0].ip' )
    echo "INGRESS_HOST=${INGRESS_HOST}"
    curl -v -k http://${INGRESS_HOST} -H 'Host: echo.example.com'

test-ingress-http:
    #!/usr/bin/env bash
    set -euo pipefail

    INGRESS_HOST=$( kubectl get svc -n projectcontour {{ loadbalancerServiceName }} -o json | jq -r '.status.loadBalancer.ingress[0].ip' )
    echo "INGRESS_HOST=${INGRESS_HOST}"
    curl -v -k http://${INGRESS_HOST} -H 'Host: echo-ingress-http.example.com'

test-ingress-https:
    #!/usr/bin/env bash
    set -euo pipefail

    INGRESS_HOST=$( kubectl get svc -n projectcontour {{ loadbalancerServiceName }} -o json | jq -r '.status.loadBalancer.ingress[0].ip' )
    echo "INGRESS_HOST=${INGRESS_HOST}"
    curl -v -k https://${INGRESS_HOST} -H 'Host: echo-ingress-http.example.com'

test-https:
    #!/usr/bin/env bash
    set -euo pipefail

    INGRESS_HOST=$( kubectl get svc -n projectcontour envoy-contour -o json | jq -r '.status.loadBalancer.ingress[0].ip' )
    echo "INGRESS_HOST=${INGRESS_HOST}"
    curl -v -k https://${INGRESS_HOST} -H 'Host: echo.example.com'

test-proxy-http:
    #!/usr/bin/env bash
    set -euo pipefail

    INGRESS_HOST=$( kubectl get svc -n projectcontour {{ loadbalancerServiceName }} -o json | jq -r '.status.loadBalancer.ingress[0].ip' )
    echo "INGRESS_HOST=${INGRESS_HOST}"
    curl -v -k http://${INGRESS_HOST} -H 'Host: echo-proxy.example.com'


test-proxy-https:
    #!/usr/bin/env bash
    set -euo pipefail

    INGRESS_HOST=$( kubectl get svc -n projectcontour {{ loadbalancerServiceName }} -o json | jq -r '.status.loadBalancer.ingress[0].ip' )
    echo "INGRESS_HOST=${INGRESS_HOST}"
    curl -v -k https://${INGRESS_HOST} -H 'Host: echo-proxy.example.com'

contour-add-helm-repo:
    helm repo add bitnami https://charts.bitnami.com/bitnami



show-envoy-logs:
    kubectl logs -l app.kubernetes.io/component=envoy -c envoy -f

show-contour-logs:
    kubectl logs -l app.kubernetes.io/component=contour  -f

show-envoy-object-graph:
    #!/usr/bin/env bash
    set -euo pipefail

    # https://projectcontour.io/docs/1.29/troubleshooting/contour-graph/

    mkdir -p target

    trap 'kill 0' EXIT
    
    CONTOUR_POD=$(kubectl -n projectcontour get pod -l app.kubernetes.io/component=contour -o name | head -1)
    echo "CONTOUR_POD=$CONTOUR_POD"
    kubectl -n projectcontour port-forward $CONTOUR_POD 6060 &
    sleep 1
    curl localhost:6060/debug/dag | dot -T png > target/contour-dag.png
    echo "view: target/contour-dag.png"