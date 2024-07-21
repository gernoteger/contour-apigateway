contour_release:="v1.29.1"
scripts:="test"/"scripts"
helm:="helm"

export CLUSTERNAME:="contourgatewayapi"
export CERT_MANAGER_VERSION:="v1.15.1"
export INGRESS_HOST:="localhost" #TODOD
@info:
    echo "contour_release={{contour_release}}"
    echo "CLUSTERNAME: ${CLUSTERNAME:-## NOT SET ##}"
    echo "SKIP_GATEWAY_API_INSTALL: ${SKIP_GATEWAY_API_INSTALL:-## NOT SET ##}"


clean:
    {{scripts}}/cleanup.sh
    rm -rf target/

setup: make-kind-cluster contour-install

make-kind-cluster:
     {{scripts}}/make-kind-cluster.sh

contour-install:
     {{scripts}}/install-contour-release.sh {{contour_release}}

template:
    {{helm}} template example charts/contour --output-dir target/templated

install:
    {{helm}} upgrade --create-namespace --install --namespace projectcontour contour charts/contour

test-http:
    #!/usr/bin/env bash
    set -euo pipefail

    INGRESS_HOST=$( kubectl get svc -n projectcontour envoy-contour -o json | jq -r '.status.loadBalancer.ingress[0].ip' )
    echo "INGRESS_HOST=${INGRESS_HOST}"
    curl -v -k http://${INGRESS_HOST} -H 'Host: echo.example.com'

test-https:
    #!/usr/bin/env bash
    set -euo pipefail

    INGRESS_HOST=$( kubectl get svc -n projectcontour envoy-contour -o json | jq -r '.status.loadBalancer.ingress[0].ip' )
    echo "INGRESS_HOST=${INGRESS_HOST}"
    curl -v -k https://${INGRESS_HOST} -H 'Host: echo.example.com'