#!/bin/bash
set -e
set -x

DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )

source /etc/kubernetes.env

start() {
  systemctl daemon-reload
  systemctl enable ${1}.service
  systemctl start ${1}.service
}

mkdir -p /etc/systemd/system/etcd2.service.d
cat <<'EOF' > /etc/systemd/system/etcd2.service.d/50-etcd.conf
[Service]
Environment=ETCD_PROXY=on
EnvironmentFile=/etc/kubernetes.env
EOF

start etcd2

mkdir -p /opt/bin

cp $DIR/install-kubernetes /opt/bin/install-kubernetes
chmod +x /opt/bin/install-kubernetes

cp $DIR/wupiao /opt/bin/wupiao
chmod +x /opt/bin/wupiao

/opt/bin/wupiao http://127.0.0.1:2379/v2/members

mkdir -p /etc/systemd/system/flanneld.service.d
cat <<'EOF' > /etc/systemd/system/flanneld.service.d/50-network-config.conf
[Unit]
Requires=etcd2.service
After=etcd2.service

[Service]
ExecStartPre=/opt/bin/wupiao http://127.0.0.1:2379/v2/members

[Install]
WantedBy=multi-user.target
EOF

start flanneld
start docker

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

start kube-kubelet

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

/opt/bin/wupiao ${KUBERNETES_MASTER}/api/v1beta3/nodes
kubectl --server=${KUBERNETES_MASTER} create -f /tmp/node.json


