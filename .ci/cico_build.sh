#!/bin/bash
# Copyright (c) 2017 Red Hat, Inc.
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Eclipse Public License v1.0
# which accompanies this distribution, and is available at
# http://www.eclipse.org/legal/epl-v10.html

# Just a script to get and build eclipse-che locally
# please send PRs to github.com/kbsingh/build-run-che

# update machine, get required deps in place
# this script assumes its being run on CentOS Linux 7/x86_64

currentDir=`pwd`
ciDir=$(dirname "$0")
ABSOLUTE_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Fetch PR and rebase on master, if job runs from PR
cat jenkins-env \
    | grep -E "(ghprbSourceBranch|ghprbPullId)=" \
    | sed 's/^/export /g' \
    > /tmp/jenkins-env
source /tmp/jenkins-env
if [[ ! -z "${ghprbPullId:-}" ]] && [[ ! -z "${ghprbSourceBranch:-}" ]]; then
  set +x
  echo 'Checking out to Github PR branch.'
  git fetch origin pull/${ghprbPullId}/head:${ghprbSourceBranch}
  git checkout ${ghprbSourceBranch}
  git fetch origin master
  git rebase FETCH_HEAD
  set -x
else
  echo 'Working on current branch of EE tests repo'
fi

if [ "$DeveloperBuild" != "true" ]
then
  set +x
  cat jenkins-env | grep -e PASS -e DEVSHIFT > inherit-env
  . inherit-env
  if [ -z "${DEVSHIFT_USERNAME+x}" ]; then echo "WARNING: failed to get DEVSHIFT_USERNAME from jenkins-env file in centos-ci job."; else export DEVSHIFT_USERNAME; fi
  if [ -z "${DEVSHIFT_PASSWORD+x}" ]; then echo "WARNING: failed to get DEVSHIFT_PASSWORD from jenkins-env file in centos-ci job."; else export DEVSHIFT_PASSWORD; fi
  if [ -z "${RHCHEBOT_DOCKER_HUB_PASSWORD+x}" ]; then echo "WARNING: failed to get RHCHEBOT_DOCKER_HUB_PASSWORD from jenkins-env file in centos-ci job."; else export RHCHEBOT_DOCKER_HUB_PASSWORD; fi
  set -x
  yum -y update
  yum -y install centos-release-scl java-1.8.0-openjdk-devel git patch bzip2 golang docker subversion
  yum -y install rh-maven33 rh-nodejs4
  
  BuildUser="chebuilder"

  useradd ${BuildUser}
  groupadd docker
  gpasswd -a ${BuildUser} docker
  
  systemctl start docker
  
  chmod a+x ..
  chown -R ${BuildUser}:${BuildUser} ${currentDir}
  
  runBuild() {
    runuser - ${BuildUser} -c "$*"
  }
else
  runBuild() {
    eval $*
  }
fi

source ${ABSOLUTE_PATH}/../config 

runBuild "cd ${ABSOLUTE_PATH} && bash ./cico_do_build_che.sh $*"
if [ $? -eq 0 ]; then
  bash ${ABSOLUTE_PATH}/cico_do_docker_build_tag_push.sh
else
  echo 'Build Failed!'
  exit 1
fi
