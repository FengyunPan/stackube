#!/bin/bash
# Copyright (c) 2017 OpenStack Foundation.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Script to install kubestack CNI on a Kubernetes host.
# - Expects the host CNI binary path to be mounted at /host/opt/cni/bin.
# - Expects the host CNI network config path to be mounted at /host/etc/cni/net.d.
# - Expects the desired CNI config in the /host/etc/cni/net.d/10-kubestack.conf.
# - Expects the desired kubestack config in the KUBESTACK_CONFIG env variable.

# Ensure all variables are defined.
set -u

# Clean up any existing binaries / config / assets.
rm -f /host/opt/cni/bin/kubestack
rm -f /host/etc/cni/net.d/10-kubestack.conf
rm -f /etc/kubestack.conf

# Place the new binaries if the directory is writeable.
if [ -w "/host/opt/cni/bin/" ]; then
	cp /opt/cni/bin/kubestack /host/opt/cni/bin/
	echo "Wrote kubestack CNI binaries to /host/opt/cni/bin/"
	echo "CNI plugin version: $(/host/opt/cni/bin/kubestack -v)"
fi

if [ ! -d /host/etc/kubestack ]; then
	mkdir -p /host/etc/kubestack
fi

# Place the new CNI network config if the directory is writeable.
if [ -w "/host/etc/cni/net.d/" ]; then
	cp /etc/cni/net.d/10-kubestack.conf /host/etc/cni/net.d/
	echo "Wrote CNI network config to /host/etc/cni/net.d/"
	echo "CNI config: $(cat /host/etc/cni/net.d/10-kubestack.conf)"
fi

TMP_CONF='/kubestack.conf.tmp'
# Check environment variables before any real actions.
for i in 'AUTH_URL' 'USERNAME' 'PASSWORD' 'TENANT_NAME' 'REGION' 'EXT_NET_ID' 'PLUGIN_NAME' 'INTEGRATION_BRIDGE';do
	if [ "${!i}" ];then
		echo "environment variable $i = ${!i}"
	else
		echo "environment variable $i is empty, exit..."
		exit
	fi
done

# Insert parameters.
sed -i s~_AUTH_URL_~${AUTH_URL:-}~g $TMP_CONF
sed -i s/_USERNAME_/${USERNAME:-}/g $TMP_CONF
sed -i s/_PASSWORD_/${PASSWORD:-}/g $TMP_CONF
sed -i s/_TENANT_NAME_/${TENANT_NAME:-}/g $TMP_CONF
sed -i s/_REGION_/${REGION:-}/g $TMP_CONF
sed -i s/_EXT_NET_ID_/${EXT_NET_ID:-}/g $TMP_CONF
sed -i s/_PLUGIN_NAME_/${PLUGIN_NAME:-}/g $TMP_CONF
sed -i s/_INTEGRATION_BRIDGE_/${INTEGRATION_BRIDGE:-}/g $TMP_CONF

# Move the temporary kubestack config into place.
KUBESTACK_CONFIG_PATH='/host/etc/kubestack/kubestack.conf'
mv $TMP_CONF $KUBESTACK_CONFIG_PATH
echo "Wrote kubestack config: $(cat ${KUBESTACK_CONFIG_PATH})"

KUBERNETES_CONFIG_PATH='/host/etc/kubestack/kubernetes.conf'
token=$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)
cacert=$(cat /var/run/secrets/kubernetes.io/serviceaccount/ca.crt | base64 | tr -d '\n')
cat > ${KUBERNETES_CONFIG_PATH} <<EOF
apiVersion: v1
clusters:
- cluster:
    certificate-authority-data: ${cacert}
    server: https://${KUBERNETES_SERVICE_HOST}:${KUBERNETES_SERVICE_PORT}
  name: kubernetes
contexts:
- context:
    cluster: kubernetes
    user: kubernetes
  name: kubernetes
current-context: kubernetes
kind: Config
preferences: {}
users:
- name: kubernetes
  user:
    token: ${token}
EOF

while true; do
	sleep 3600;
done
