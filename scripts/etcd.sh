#!/bin/bash
set -e
set -x

source /etc/kubernetes.env
source /etc/network.env


start() {
  systemctl daemon-reload
  systemctl enable ${1}.service
  systemctl start ${1}.service
}


cat <<EOF > /etc/etcd.env
ETCD_LISTEN_CLIENT_URLS=http://0.0.0.0:2379
ETCD_LISTEN_PEER_URLS=http://0.0.0.0:2380
ETCD_INITIAL_ADVERTISE_PEER_URLS=http://${PRIVATE_IP}:2380
ETCD_ADVERTISE_CLIENT_URLS=http://${PRIVATE_IP}:2379
EOF

mkdir -p /etc/systemd/system/etcd2.service.d
cat <<EOF > /etc/systemd/system/etcd2.service.d/50-etcd.conf
[Service]
EnvironmentFile=/etc/kubernetes.env
EnvironmentFile=/etc/etcd.env
EOF

start etcd2

