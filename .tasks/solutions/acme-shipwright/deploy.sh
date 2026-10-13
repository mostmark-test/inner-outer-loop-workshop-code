#!/bin/bash
#######################################
# ACME Shipwright Solution            #
#######################################
#
# Builds acme-hello with Shipwright and deploys it. Can run again: it reuses what exists.
#
# Usage: deploy.sh [PROJECT]   (default: acme-<user>)

DIRECTORY="$(cd "$(dirname "$0")" && pwd)"
. "${DIRECTORY}/../../workshop-env.sh"
PROJECT_NAME="${1:-acme-${WORKSHOP_USER}}"
IMAGE="image-registry.openshift-image-registry.svc:5000/${PROJECT_NAME}/acme-hello:latest"

"${DIRECTORY}/../../acme_build_shipwright.sh" "${PROJECT_NAME}" || exit 1

oc create deployment acme-hello --image="${IMAGE}" --port=8080 -n "${PROJECT_NAME}" --dry-run=client -o yaml \
  | oc apply -f - > /dev/null || exit 1
oc rollout restart deployment/acme-hello -n "${PROJECT_NAME}" > /dev/null
oc get service acme-hello -n "${PROJECT_NAME}" > /dev/null 2>&1 || oc expose deployment acme-hello --port=8080 -n "${PROJECT_NAME}"
oc get route acme-hello -n "${PROJECT_NAME}" > /dev/null 2>&1 || oc expose service acme-hello -n "${PROJECT_NAME}"

echo "ACME Hello Deployed: http://$(oc get route acme-hello -n "${PROJECT_NAME}" -o jsonpath='{.spec.host}')"