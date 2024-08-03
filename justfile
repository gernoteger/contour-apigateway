contour_release:="v1.29.1"
scripts:="test"/"scripts"
helm:="helm"

skipGatewayApi:="false"
skipCRDs:="false"

helmSkipCRDS:="--skip-crds"

#helmNamespaceReleaseChartStanza:="--namespace projectcontour contour charts/contour"
#helmNamespaceReleaseChartStanza:="--namespace projectcontour ${chart} charts/${chart} "

export CLUSTERNAME:="contourgatewayapi"
export CERT_MANAGER_VERSION:="v1.15.1"
export INGRESS_HOST:="localhost" #TODO

@info:
    echo "contour_release={{contour_release}}"
    echo "CLUSTERNAME: ${CLUSTERNAME:-## NOT SET ##}"
    echo "SKIP_GATEWAY_API_INSTALL: ${SKIP_GATEWAY_API_INSTALL:-## NOT SET ##}"
    echo "SKIP_CRD_INSTALL: ${SKIP_CRD_INSTALL:-## NOT SET ##}"

# charts:="contour payload"

clean: stop-kind-cluster
    rm -rf target/

start-cluster: make-kind-cluster
stop-cluster: stop-kind-cluster
    
make-kind-cluster:
    {{scripts}}/make-kind-cluster.sh
    {{scripts}}/install-gatewayapi-crds.sh
#    {{scripts}}/install-contour-crds.sh

stop-kind-cluster:
    {{scripts}}/cleanup.sh # uses  ${CLUSTERNAME}

install-contour-script:
     {{scripts}}/install-contour-release.sh {{contour_release}}

template:
    rm -rf  target/templated
    #{{ just_executable() }} template-chart projectcontour contour
    {{ just_executable() }} template-chart istio-system istio
    {{ just_executable() }} template-chart ingress payload
 
install: template
    #{{ just_executable() }} install-chart projectcontour contour
    {{ just_executable() }} install-chart istio-system istio
    {{ just_executable() }} install-chart ingress payload

dependency-update:
    #{{ just_executable() }} dependency-update-chart projectcontour contour
    {{ just_executable() }} dependency-update-chart istio-system istio
    {{ just_executable() }} dependency-update-chart ingress payload

template-chart namespace chart:
    #!/usr/bin/env bash
    set -euo pipefail

    rm -rf  target/templated/{{ chart }}
    {{helm}} template {{ helmSkipCRDS }} --namespace {{ namespace }} {{ chart }} charts/{{ chart }} --output-dir target/templated/{{ chart }}

install-chart namespace chart:
    {{helm}} upgrade {{ helmSkipCRDS }} --create-namespace --install --namespace {{ namespace }} {{ chart }} charts/{{ chart }}

# dependency-build:
#     {{helm}} dependency build --namespace projectcontour charts/contour


dependency-update-chart namespace chart:
    {{helm}} dependency update --namespace {{ namespace }} charts/{{ chart }}

dependency-expand:
    mkdir -p target/dependencies
    tar -xzf charts/contour/charts/contour-*.tgz --directory target/dependencies


# istio
#https://istio.io/latest/docs/setup/install/helm/
install-istio-helm-repo:
    helm repo add istio https://istio-release.storage.googleapis.com/charts
    helm repo update

install-istio-ctl: 
    # https://istio.io/latest/docs/ops/diagnostic-tools/istioctl/
    #!/usr/bin/env bash
    set -euo pipefail
    cd target
    curl -sL https://istio.io/downloadIstioctl | sh -



# https://github.com/istio/istio/tree/master/manifests/charts/istio-control/istio-discovery
install-istio-helm: # TODO: just a test # see https://istio.io/latest/docs/setup/install/helm/
    #!/usr/bin/env bash
    set -euo pipefail

    helm upgrade --install istio-base istio/base -n istio-system --create-namespace --set defaultRevision=default

    # check deployment success
    #helm ls -n istio-system | grep -ic deployed

    echo "installing discovery service..."
    # TODO: how to configure?
    # https://github.com/istio/istio/tree/master/manifests/charts/istio-control/istio-discovery
    # nned toenable TLSRoute 
    # extraContainerArgs
    helm template istiod istio/istiod -n istio-system --values istio-values.yaml --output-dir target/templated/istio-helm
    helm upgrade --install istiod istio/istiod -n istio-system --values istio-values.yaml --wait 

    #echo "istio config:"
    #kubectl get cm istio -o json | jq -r .data.mesh

install-istio-istioctl: # TODO: for testing
    # namspaces are ignored!
    istioctl install -y --set profile=minimal --namespace default2 --istioNamespace istio-system2 -f istioconfig.yaml

# go tests
test:
    #!/usr/bin/env bash
    set -euo pipefail
    cd  test/testcases
    # go test -v 
    {{ just_executable() }} test

# smoke tests
test-get-echo url:
    #!/usr/bin/env bash
    set -euo pipefail

    # assume only one ingress with loadbalancer!
    INGRESS_IP=$( kubectl get svc -o json | jq -r '[.items[] |select(.spec.type == "LoadBalancer")] | .[0].status.loadBalancer.ingress[0].ip')
    
    VERBOSE=
    VERBOSE=-vi
    echo "INGRESS_IP=${INGRESS_IP}"
    curl -ks ${VERBOSE} --connect-to "::${INGRESS_IP}:" {{ url }}

test-ingress-http:
    @{{ just_executable() }} test-get-echo "http://echo-ingress-http.example.com"

test-ingress-https:
    @{{ just_executable() }} test-get-echo "https://echo-ingress-https.example.com"

test-http:
    @{{ just_executable() }} test-get-echo "http://echo.example.com"
test-https:
    @{{ just_executable() }} test-get-echo "https://echo.example.com"

test-tlsroute:
    @{{ just_executable() }} test-get-echo "https://echo-tls.example.com" 

test-proxy-http:
    @{{ just_executable() }} test-get-echo "http://echo-proxy-http.example.com"


test-proxy-https:
    @{{ just_executable() }} test-get-echo "https://echo-proxy-https.example.com"
 
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

forward-envoy-admin-interface:
    #!/usr/bin/env bash
    set -euo pipefail
    # https://projectcontour.io/docs/1.29/troubleshooting/envoy-admin-interface/
    # Get one of the pods that matches the Envoy daemonset
    ENVOY_POD=$(kubectl -n projectcontour get pod -l app.kubernetes.io/component=envoy -o name | head -1)
    # Do the port forward to that pod
    echo  "get config with `curl http://127.0.0.1:9001/config_dump > target/envoy_config.json`"
    kubectl -n projectcontour port-forward $ENVOY_POD 9001
