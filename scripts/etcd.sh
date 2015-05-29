#!/bin/bash
set -e
set -x

source /etc/kubernetes.env
source /etc/network.env

DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )

source $DIR/functions.sh

setup-install-etcd

cat <<EOF > /etc/etcd.env
ETCD_LISTEN_CLIENT_URLS=http://0.0.0.0:2379
ETCD_LISTEN_PEER_URLS=http://0.0.0.0:2380
ETCD_INITIAL_ADVERTISE_PEER_URLS=http://${PRIVATE_IP}:2380
ETCD_ADVERTISE_CLIENT_URLS=http://${PRIVATE_IP}:2379
EOF

cat <<'EOF' > /etc/systemd/system/etcd.service
[Unit]
Description=etcd

[Service]
EnvironmentFile=/etc/kubernetes.env
EnvironmentFile=/etc/etcd.env
Environment=ETCD_DATA_DIR=/var/lib/etcd2
Environment=ETCD_NAME=%m
User=etcd
PermissionsStartOnly=true
ExecStartPre=/opt/bin/install-etcd
ExecStart=/opt/bin/etcd
Restart=always
RestartSec=10s
LimitNOFILE=40000

[Install]
WantedBy=multi-user.target
EOF

start etcd

