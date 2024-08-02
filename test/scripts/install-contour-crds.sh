#! /usr/bin/env bash

set -o pipefail
set -o errexit
set -o nounset


readonly KUBECTL=${KUBECTL:-kubectl}


readonly HERE=$(cd "$(dirname "$0")" && pwd)
readonly REPO=$(cd "${HERE}/../.." && pwd)

# Install Contour CRDs.
${KUBECTL} apply -f "${REPO}/crds/contour/crds.yaml"

