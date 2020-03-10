#!/bin/bash

# DR Cluster Parameters
CONTEXT_NAME="dr"

# Codeready Parameters
CODEREADY_DEVFILE_URL="https://raw.githubusercontent.com/ably77/openshift-testbed-argo-codeready/master/dev-file/strimzi-demo-devfile.yaml"
CODEREADY_NAMESPACE="codeready"

# Don't change unless you change argocd/<app>.yaml namespace pointers
KAFKA_NAMESPACE="myproject"
GRAFANA_NAMESPACE="myproject"

#### Create demo CRDs
oc create -f crds/ --context=${CONTEXT_NAME}

### Check if argocd CLI is installed
ARGOCLI=$(which argocd)
echo checking if argocd CLI is installed
if [[ $ARGOCLI == "" ]]
then
        echo
        echo "argocd CLI not installed"
        echo "see https://github.com/argoproj/argo-cd/blob/master/docs/cli_installation.md for installation instructions"
        echo "re-run the script after argocd CLI is installed"
        echo
        exit 1
fi

### Add dr context to argocd
argocd cluster add ${CONTEXT_NAME}

### create argocd dr project
oc create -f dr/dr-project.yaml

### create dr applications
oc create -f dr/apps/1/

### check kafka deployment status
echo waiting for kafka deployment to complete
./extras/wait-for-condition-context.sh my-cluster-kafka-2 ${KAFKA_NAMESPACE} ${CONTEXT_NAME}

### check grafana deployment status
echo checking grafana deployment status before deploying applications
./extras/wait-for-condition-context.sh grafana-deployment ${GRAFANA_NAMESPACE} ${CONTEXT_NAME}

### deploy IoT demo and load test application in argocd
oc create -f dr/apps/2/

### open grafana route
echo opening grafana route
grafana_route=$(oc get routes -n ${GRAFANA_NAMESPACE} --context ${CONTEXT_NAME} | grep grafana-route | awk '{ print $2 }')
open https://${grafana_route}

### Wait for IoT Demo
./extras/wait-for-condition-context.sh consumer-app myproject ${CONTEXT_NAME}

### open IoT demo app route
echo opening consumer-app route
iot_route=$(oc get routes -n ${KAFKA_NAMESPACE} --context ${CONTEXT_NAME} | grep consumer-app-myproject.apps | awk '{ print $2 }')
open http://${iot_route}

### switch to codeready namespace
oc project codeready

### wait for codeready workspace to deploy
./extras/wait-for-rollout.sh deployment codeready codeready

### create/open codeready workspace from custom URL dev-file.yaml
echo deploying codeready workspace
CHE_HOST=$(oc get routes -n ${CODEREADY_NAMESPACE} --context ${CONTEXT_NAME} | grep codeready-codeready.apps | awk '{ print $2 }')
open http://${CHE_HOST}/f?url=${CODEREADY_DEVFILE_URL}

### end
echo
echo installation complete
echo
echo
echo links to console routes:
echo
echo iot demo-dr console:
echo http://${iot_route}
echo
echo grafana-dr dashboards:
echo https://${grafana_route}
echo
echo codeready workspaces: create a new user to initiate workspace build
echo http://${CHE_HOST}/f?url=${CODEREADY_DEVFILE_URL}
echo