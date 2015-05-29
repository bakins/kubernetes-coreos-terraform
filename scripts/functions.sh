#!/bin/bash

DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )


enable() {
  systemctl daemon-reload
  systemctl enable ${1}.service
}

start() {
  systemctl daemon-reload
  systemctl enable ${1}.service
  systemctl start ${1}.service
}

setup-install-etcd() {
  mkdir -p /opt/bin
  cp $DIR/install-etcd /opt/bin/install-etcd
  chmod +x /opt/bin/install-etcd
}

setup-install-kubernetes() {
  mkdir -p /opt/bin
  cp $DIR/install-kubernetes /opt/bin/install-kubernetes
  chmod +x /opt/bin/install-kubernetes
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
}

setup-wupiao() {
  mkdir -p /opt/bin
  cp $DIR/wupiao /opt/bin/wupiao
  chmod +x /opt/bin/wupiao
}
