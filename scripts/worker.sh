#!/bin/bash
set -e
set -x

DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )

source /etc/kubernetes.env
source $DIR/functions.sh

setup-install-etcd
setup-install-kubernetes
setup-wupiao

cat <<'EOF' > /etc/systemd/system/etcd.service
[Unit]
Description=etcd

[Service]
Environment=ETCD_PROXY=on
EnvironmentFile=/etc/kubernetes.env
ExecStartPre=/opt/bin/install-etcd
ExecStart=/opt/bin/etcd
Restart=always
RestartSec=10s
LimitNOFILE=40000

[Install]
WantedBy=multi-user.target
EOF

mkdir -p /etc/systemd/system/flanneld.service.d
cat <<'EOF' > /etc/systemd/system/flanneld.service.d/50-network-config.conf
[Unit]
Requires=etcd.service
After=etcd.service

[Service]
ExecStartPre=/opt/bin/wupiao http://127.0.0.1:2379/v2/members

[Install]
WantedBy=multi-user.target
EOF

cat <<'EOF' > /etc/systemd/system/install-kubernetes.service
[Unit]
Description=Install Kubernetes
Documentation=https://github.com/GoogleCloudPlatform/kubernetes
Requires=network-online.target
After=network-online.target

[Service]
EnvironmentFile=/etc/kubernetes.env
ExecStart=/opt/bin/install-kubernetes
Type=oneshot
RemainAfterExit=true

[Install]
WantedBy=multi-user.target
EOF


cat <<'EOF' > /etc/systemd/system/kube-kubelet.service
[Unit]
Description=Kubernetes Kubelet Server
Documentation=https://github.com/GoogleCloudPlatform/kubernetes
After=install-kubernetes.service
Requires=install-kubernetes.service

[Service]
EnvironmentFile=/etc/kubernetes.env
ExecStartPre=/opt/bin/wupiao ${KUBERNETES_MASTER}/api/v1beta3/nodes
ExecStart=/opt/bin/kubelet \
  --api-servers=${KUBERNETES_MASTER}
  --allow-privileged==true \
  --logtostderr=true \
  --v=2 \
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

cat <<'EOF' > /etc/systemd/system/kube-proxy.service
[Unit]
Description=Kubernetes Proxy Server
Documentation=https://github.com/GoogleCloudPlatform/kubernetes
After=install-kubernetes.service
Requires=install-kubernetes.service

[Service]
EnvironmentFile=/etc/kubernetes.env
ExecStartPre=/opt/bin/wupiao ${KUBERNETES_MASTER}/api/v1beta3/nodes
ExecStart=/opt/bin/kubelet \
  --master==${KUBERNETES_MASTER}
  --logtostderr=true \
  --v=2
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

H=`hostname -f`
cat <<EOF > /tmp/node.json
{
  "kind": "Node",
  "apiVersion": "v1beta3",
  "metadata": {
    "name": "${H}"
  }
}
EOF


for S in etcd flanneld docker kube-kubelet kube-proxy; do
  start $S
done

/opt/bin/wupiao ${KUBERNETES_MASTER}/api/v1beta3/nodes
kubectl --server=${KUBERNETES_MASTER} create -f /tmp/node.json


