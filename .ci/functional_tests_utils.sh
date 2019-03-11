#!/usr/bin/env bash

# Copyright (c) 2017 Red Hat, Inc.
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Eclipse Public License v1.0
# which accompanies this distribution, and is available at
# http://www.eclipse.org/legal/epl-v10.html

function installOC() {
	OC_VERSION=3.10.90
	curl -s "https://mirror.openshift.com/pub/openshift-v3/clients/${OC_VERSION}/linux/oc.tar.gz" | tar xvz -C /usr/local/bin
}

function installJQ() {
	installEpelRelease
	yum install --assumeyes -q jq
}

function installEpelRelease() {
	yum install epel-release --assumeyes
	yum update --assumeyes
}

function installYQ() {
	installEpelRelease
	yum install python-pip --assumeyes
	pip install yq
}

function installStartDocker() {
	yum install --assumeyes docker
	systemctl start docker
}

function installMvn() {
	yum install --assumeyes rh-maven33
}

function installNodejs() {
	yum install --assumeyes rh-nodejs8
}

function installDependencies() {
	installEpelRelease
	installYQ
	installStartDocker
	installJQ
	installOC
	
	# Getting dependencies ready
	yum install --assumeyes \
	            git \
	            patch \
	            pcp \
	            bzip2 \
	            golang \
	            make \
	            java-1.8.0-openjdk \
	            java-1.8.0-openjdk-devel \
	            centos-release-scl
	installNodejs
	installMvn
}

function checkAllCreds() {
	CREDS_NOT_SET="false"

	if [[ -z "${QUAY_USERNAME}" || -z "${QUAY_PASSWORD}" ]]; then
	  echo "Docker registry credentials not set"
	  CREDS_NOT_SET="true"
	fi
	
	if [[ -z "${RH_CHE_AUTOMATION_DEV_CLUSTER_SA_TOKEN}" ]]; then
	  echo "RDU2C credentials not set"
	  CREDS_NOT_SET="true"
	fi

	if [[ -z "${RH_CHE_AUTOMATION_CHE_PREVIEW_EMAIL}" ]] ||
	   [[ -z "${RH_CHE_AUTOMATION_CHE_PREVIEW_USERNAME}" ]] ||
	   [[ -z "${RH_CHE_AUTOMATION_CHE_PREVIEW_PASSWORD}" ]]; then
	  echo "Prod-preview credentials not set."
	  CREDS_NOT_SET="true"
	fi
	
	if [[ "${CREDS_NOT_SET}" = "true" ]]; then
	  echo "Failed to parse jenkins secure store credentials"
	  exit 2
	else
	  echo "Credentials set successfully."
	fi
}

function archiveArtifacts() {
  echo "Archiving artifacts from ${DATE} for ${JOB_NAME}/${BUILD_NUMBER}"
  ls -la ./artifacts.key
  chmod 600 ./artifacts.key
  chown $(whoami) ./artifacts.key
  mkdir -p ./rhche/${JOB_NAME}/${BUILD_NUMBER}/surefire-reports
  cp ./logs/*.log ./rhche/${JOB_NAME}/${BUILD_NUMBER}/
  cp -R ./logs/artifacts/screenshots/ ./rhche/${JOB_NAME}/${BUILD_NUMBER}/
	cp -R ./logs/artifacts/failsafe-reports/ ./rhche/${JOB_NAME}/${BUILD_NUMBER}/
  rsync --password-file=./artifacts.key -PHva --relative ./rhche/${JOB_NAME}/${BUILD_NUMBER} devtools@artifacts.ci.centos.org::devtools/
}
