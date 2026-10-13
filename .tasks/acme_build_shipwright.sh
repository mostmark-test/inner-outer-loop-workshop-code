#!/bin/bash
################################
# ACME - Build with Shipwright #
################################
#
# Defines the Build acme-hello in the participant's project acme-<user>, starts a BuildRun and
# waits until it has finished.
#
# Usage: acme_build_shipwright.sh [PROJECT]   (default: acme-<user>)

DIRECTORY="$(cd "$(dirname "$0")" && pwd)"
. "${DIRECTORY}/workshop-env.sh"
PROJECT_NAME="${1:-acme-${WORKSHOP_USER}}"

workshop_login || exit 1
oc project "${PROJECT_NAME}" > /dev/null || exit 1

info "Defining the Build acme-hello in ${PROJECT_NAME}"
oc apply -f - <<EOF || exit 1
apiVersion: shipwright.io/v1beta1
kind: Build
metadata:
  name: acme-hello
spec:
  source:
    type: Git
    git:
      url: ${CODE_REPO_URL}
      revision: ${CODE_REPO_REVISION}
    contextDir: labs/acme-hello
  strategy:
    kind: ClusterBuildStrategy
    name: buildah
  output:
    image: image-registry.openshift-image-registry.svc:5000/${PROJECT_NAME}/acme-hello:latest
EOF

BUILDRUN=$(oc create -o name -f - <<EOF | cut -d/ -f2
apiVersion: shipwright.io/v1beta1
kind: BuildRun
metadata:
  generateName: acme-hello-
spec:
  build:
    name: acme-hello
EOF
)
[ -n "${BUILDRUN}" ] || { fail "Could not start a BuildRun"; exit 1; }
info "Started BuildRun ${BUILDRUN}; waiting until it has finished (the first build takes about two minutes)"

for i in $(seq 1 180); do
  STATUS=$(oc get buildruns.shipwright.io "${BUILDRUN}" -o jsonpath='{.status.conditions[?(@.type=="Succeeded")].status}')
  REASON=$(oc get buildruns.shipwright.io "${BUILDRUN}" -o jsonpath='{.status.conditions[?(@.type=="Succeeded")].reason}')
  [ "${STATUS}" = "True" ] || [ "${STATUS}" = "False" ] && break
  [ $((i % 6)) -eq 0 ] && info "  ${BUILDRUN}: ${REASON:-Pending}"
  sleep 5
done

POD="$(oc get buildruns.shipwright.io "${BUILDRUN}" -o jsonpath='{.status.taskRunName}')-pod"
oc logs "${POD}" -c step-build-and-push --tail=5 2> /dev/null
if [ "${STATUS}" != "True" ]; then
  fail "BuildRun ${BUILDRUN} did not succeed (${REASON:-timeout}). Details: oc describe buildruns.shipwright.io ${BUILDRUN}"
  exit 1
fi
ok "BuildRun ${BUILDRUN} succeeded: image ${PROJECT_NAME}/acme-hello:latest"