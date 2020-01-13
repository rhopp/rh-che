#!/usr/bin/env bash
# Copyright (c) 2018 Red Hat, Inc.
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Eclipse Public License v1.0
# which accompanies this distribution, and is available at
# http://www.eclipse.org/legal/epl-v10.html

set -e

echo "****** Starting RH-Che PR check $(date) ******"
total_start_time=$(date +%s)
export PR_CHECK_BUILD="true"
export BASEDIR=$(pwd)
export DEV_CLUSTER_URL=https://devtools-dev.ext.devshift.net:8443/

eval "$(./env-toolkit load -f jenkins-env.json -r \
        ^DEVSHIFT_TAG_LEN$ \
        ^QUAY_ \
        ^KEYCLOAK \
        ^BUILD_NUMBER$ \
        ^JOB_NAME$ \
        ^ghprb \
        ^RH_CHE)"

source ./config
source .ci/functional_tests_utils.sh

echo "Checking credentials:"
checkAllCreds

echo "Installing dependencies:"
start=$(date +%s)
installDependencies
stop=$(date +%s)
instal_dep_duration=$(($stop - $start))
echo "Installing all dependencies lasted $instal_dep_duration seconds."

### DO NOT MERGE!!!
set -x
nmcli > nmclioutput
cat nmclioutput

firewall-cmd --permanent --new-zone dockerc
firewall-cmd --permanent --zone dockerc --add-source 172.17.0.0/16
firewall-cmd --permanent --zone dockerc --add-port 8443/tcp
firewall-cmd --permanent --zone dockerc --add-port 53/udp
firewall-cmd --permanent --zone dockerc --add-port 8053/udp
firewall-cmd --reload


LOCAL_IP_ADDRESS=$(ip a show | grep -e "scope.*eth0" | grep -v ':' | cut -d/ -f1 | awk 'NR==1{print $2}')
echo $LOCAL_IP_ADDRESS

oc cluster up --public-hostname="${LOCAL_IP_ADDRESS}" --routing-suffix="${LOCAL_IP_ADDRESS}.nip.io" --loglevel=6

oc login -u system:admin
oc adm policy add-cluster-role-to-user cluster-admin developer
oc login -u developer -p pass

bash <(curl -sL  https://www.eclipse.org/che/chectl/) --channel=next

if chectl server:start -a operator -p openshift
then
        echo "Started succesfully"
else
        oc get events
        oc get all
        exit 1337

CHE_ROUTE=$(oc get route che --template='{{ .spec.host }}')

docker run --shm-size=256m -e TS_SELENIUM_BASE_URL="http://$CHE_ROUTE" eclipse/che-e2e:nightly

set +x
### DO NOT MERGE!!!

# export PROJECT_NAMESPACE=prcheck-${RH_PULL_REQUEST_ID}
# export DOCKER_IMAGE_TAG="${RH_TAG_DIST_SUFFIX}"-"${RH_PULL_REQUEST_ID}"
# CHE_VERSION=$(getVersionFromPom)
# export CHE_VERSION

# echo "Running ${JOB_NAME} PR: #${RH_PULL_REQUEST_ID}, build number #${BUILD_NUMBER} for che-version:${CHE_VERSION}"
# .ci/cico_build_deploy_test_rhche.sh

# end_time=$(date +%s)
# whole_check_duration=$(($end_time - $total_start_time))
# echo "****** PR check ended at $(date) and whole run took $whole_check_duration seconds. ******"
