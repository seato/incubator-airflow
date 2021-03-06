# Licensed to the Apache Software Foundation (ASF) under one
# or more contributor license agreements.  See the NOTICE file
# distributed with this work for additional information
# regarding copyright ownership.  The ASF licenses this file
# to you under the Apache License, Version 2.0 (the
# "License"); you may not use this file except in compliance
# with the License.  You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing,
# software distributed under the License is distributed on an
# "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
# KIND, either express or implied.  See the License for the
# specific language governing permissions and limitations
# under the License.

# This script was based on one made by @kimoonkim for kubernetes-hdfs

#!/usr/bin/env bash

_MY_SCRIPT="${BASH_SOURCE[0]}"
_MY_DIR=$(cd "$(dirname "$_MY_SCRIPT")" && pwd)
# Avoids 1.7.x because of https://github.com/kubernetes/minikube/issues/2240
_KUBERNETES_VERSION="${KUBERNETES_VERSION}"

echo "setting up kubernetes ${_KUBERNETES_VERSION}"

_MINIKUBE_VERSION="v0.25.2"
_HELM_VERSION=v2.8.1
_VM_DRIVER=none
USE_MINIKUBE_DRIVER_NONE=true

_UNAME_OUT=$(uname -s)
case "${_UNAME_OUT}" in
    Linux*)     _MY_OS=linux;;
    Darwin*)    _MY_OS=darwin;;
    *)          _MY_OS="UNKNOWN:${unameOut}"
esac
echo "Local OS is ${_MY_OS}"

export MINIKUBE_WANTUPDATENOTIFICATION=false
export MINIKUBE_WANTREPORTERRORPROMPT=false
export CHANGE_MINIKUBE_NONE_USER=true

cd $_MY_DIR

rm -rf tmp
mkdir -p bin tmp

sudo mkdir -p /usr/local/bin

if [[ ! -x /usr/local/bin/kubectl ]]; then
  echo Downloading kubectl, which is a requirement for using minikube.
  curl -Lo bin/kubectl  \
    https://storage.googleapis.com/kubernetes-release/release/${_KUBERNETES_VERSION}/bin/${_MY_OS}/amd64/kubectl
  chmod +x bin/kubectl
fi
if [[ ! -x /usr/local/bin/minikube ]]; then
  echo Downloading minikube.
  curl -Lo bin/minikube  \
    https://storage.googleapis.com/minikube/releases/${_MINIKUBE_VERSION}/minikube-${_MY_OS}-amd64
  chmod +x bin/minikube
fi

sudo mv bin/minikube /usr/local/bin/minikube
sudo mv bin/kubectl /usr/local/bin/kubectl

export PATH="${_MY_DIR}/bin:$PATH"

if [[ "${USE_MINIKUBE_DRIVER_NONE:-}" = "true" ]]; then
  # Run minikube with none driver.
  # See https://blog.travis-ci.com/2017-10-26-running-kubernetes-on-travis-ci-with-minikube
  _VM_DRIVER="--vm-driver=none"
  if [[ ! -x /usr/local/bin/nsenter ]]; then
    # From https://engineering.bitnami.com/articles/implementing-kubernetes-integration-tests-in-travis.html
    # Travis ubuntu trusty env doesn't have nsenter, needed for --vm-driver=none
    which nsenter >/dev/null && return 0
    echo "INFO: Building 'nsenter' ..."
cat <<-EOF | docker run -i --rm -v "$(pwd):/build" ubuntu:14.04 >& nsenter.build.log
        apt-get update
        apt-get install -qy git bison build-essential autopoint libtool automake autoconf gettext pkg-config
        git clone --depth 1 git://git.kernel.org/pub/scm/utils/util-linux/util-linux.git /tmp/util-linux
        cd /tmp/util-linux
        ./autogen.sh
        ./configure --without-python --disable-all-programs --enable-nsenter
        make nsenter
        cp -pfv nsenter /build
EOF
    if [ ! -f ./nsenter ]; then
        echo "ERROR: nsenter build failed, log:"
        cat nsenter.build.log
        return 1
    fi
    echo "INFO: nsenter build OK"
    sudo mv ./nsenter /usr/local/bin
  fi
fi

echo "your path is ${PATH}"

_MINIKUBE="sudo PATH=$PATH minikube"

$_MINIKUBE config set bootstrapper localkube
$_MINIKUBE start --kubernetes-version=${_KUBERNETES_VERSION}  --vm-driver=none
$_MINIKUBE update-context
