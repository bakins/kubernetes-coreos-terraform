#!/bin/bash
set -e
set -x

source /etc/kubernetes.env

DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )

start() {
  systemctl daemon-reload
  systemctl enable ${1}.service
  systemctl start ${1}.service
}

mkdir -p /etc/systemd/system/etcd2.service.d
cat <<EOF > /etc/systemd/system/etcd2.service.d/50-etcd.conf
[Service]
Environment=ETCD_PROXY=on
EnvironmentFile=/etc/kubernetes.env

[Install]
WantedBy=multi-user.target
EOF

mkdir -p /opt/bin

cp $DIR/install-kubernetes /opt/bin/install-kubernetes
chmod +x /opt/bin/install-kubernetes

cp $DIR/wupiao /opt/bin/wupiao
chmod +x /opt/bin/wupiao


cat <<EOF > /etc/systemd/system/install-kubernetes.service
[Unit]
Description=Install Kubernetes
Documentation=https://github.com/GoogleCloudPlatform/kubernetes
Requires=network-online.target
After=network-online.target

[Service]
ExecStart=/opt/bin/install-kubernetes
Type=oneshot
RemainAfterExit=true

[Install]
WantedBy=multi-user.target
EOF


cat <<EOF > /etc/systemd/system/kube-apiserver.service
[Unit]
Description=Kubernetes API Server
Documentation=https://github.com/GoogleCloudPlatform/kubernetes
After=install-kubernetes.service docker.service flanneld.service
Requires=install-kubernetes.service docker.service flanneld.service

[Service]
EnvironmentFile=/etc/kubernetes.env
ExecStartPre=/opt/bin/wupiao http://127.0.0.1:2379/v2/members
ExecStart=/opt/bin/kube-apiserver \
  --insecure-bind-address=0.0.0.0 \
  --allow-privileged=true \
  --etcd-servers=http://127.0.0.1:2379 \
  --logtostderr=true \
  --insecure-port=8080 \
  --token_auth_file=/etc/kubernetes/tokens.csv \
  --v=2 \
  --portal-net=${KUBERNETES_PORTAL_NET}
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

mkdir -p /etc/systemd/system/flanneld.service.d
cat <<EOF > /etc/systemd/system/flanneld.service.d/50-network-config.conf
[Unit]
Requires=etcd2.service
After=etcd2.service

[Service]
EnvironmentFile=/etc/kubernetes.env
ExecStartPre=/opt/bin/wupiao http://127.0.0.1:2379/v2/members
ExecStartPre=/usr/bin/etcdctl --no-sync set /coreos.com/network/config '{ "Network": "${KUBERNETES_CONTAINERS_CIDR}", "Backend":{"Type": "vxlan"} }'

[Install]
WantedBy=multi-user.target
EOF

cat <<EOF > /etc/systemd/system/kube-scheduler.service
[Unit]
Description=Kubernetes Scheduler
Documentation=https://github.com/GoogleCloudPlatform/kubernetes
Requires=kube-apiserver.service
After=kube-apiserver.service

[Service]
EnvironmentFile=/etc/kubernetes.env
ExecStartPre=/opt/bin/wupiao http://127.0.0.1:8080/api/v1beta3/nodes
ExecStart=/opt/bin/kube-scheduler \
  --logtostderr=true \
  --master=http://127.0.0.1:8080 \
  --v=2
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

cat <<EOF > /etc/systemd/system/kube-controller-manager.service
[Unit]
Description=Kubernetes Controller Manager
Documentation=https://github.com/GoogleCloudPlatform/kubernetes
Requires=kube-apiserver.service
After=kube-apiserver.service

[Service]
EnvironmentFile=/etc/kubernetes.env
ExecStartPre=/opt/bin/wupiao http://127.0.0.1:8080/api/v1beta3/nodes
ExecStart=/opt/bin/kube-controller-manager \
  --logtostderr=true \
  --master=http://127.0.0.1:8080 \
  --v=2 \
  --cluster-cidr=${KUBERNETES_CONTAINERS_CIDR}
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

for S in etcd2 flanneld kube-apiserver kube-scheduler kube-controller-manager; do
  start $S
done
