#!/bin/bash
#
# "OpenShift - Cleanup": resets the workshop so it can be started again.
#   - reverts local changes of the workshop repository (labs/, generated labs/gitops),
#   - deletes the Coolstore resources in my-project-<user> and cn-project-<user>
#     (the projects themselves are pre-created by the workshop and are kept),
#   - deletes the participant's Argo CD Applications <svc>-<user> (without cascading).
#   - deletes the participant's Argo CD Applications <svc>-<user> (without cascading),
#   - deletes the ACME Hello build and deployment in acme-<user>.
# Gitea repositories are kept; the fast-forward scripts re-create the ones they need.
#
# Usage: openshift_cleanup.sh [USER]   (default: the workspace user)

DIRECTORY="$(cd "$(dirname "$0")" && pwd)"
. "${DIRECTORY}/workshop-env.sh"
workshop_set_user "$1"

info "Reverting local changes in ${WORKSHOP_DIR}"
rm -rf "${WORKSHOP_DIR}/labs/inventory-quarkus/.git" "${WORKSHOP_DIR}/labs/gitops"
git -C "${WORKSHOP_DIR}" checkout -- .
git -C "${WORKSHOP_DIR}" clean -fdq

workshop_login || exit 1

if argocd_env 2> /dev/null; then
  for app in inventory catalog gateway web; do
    workshop_argocd app delete "${app}-${WORKSHOP_USER}" --cascade=false --yes > /dev/null 2>&1 &&
      info "Deleted Argo CD Application ${app}-${WORKSHOP_USER}"
  done
fi

workshop_clean_project "${DEV_PROJECT}"
workshop_clean_project "${STAGING_PROJECT}"

# ACME: the Shipwright exercise in acme-<user>. Shipwright runs each build as a Tekton TaskRun,
# which stays when its BuildRun is deleted; it keeps the build pod.
info "Deleting the ACME Hello resources in acme-${WORKSHOP_USER}"
oc delete buildruns.shipwright.io,taskruns.tekton.dev,builds.shipwright.io,deployment,service,route,imagestream \
  --all -n "acme-${WORKSHOP_USER}" --ignore-not-found > /dev/null 2>&1

oc project "${DEV_PROJECT}" > /dev/null 2>&1
ok "Cleanup done: ${DEV_PROJECT} and ${STAGING_PROJECT} no longer contain Coolstore resources"
