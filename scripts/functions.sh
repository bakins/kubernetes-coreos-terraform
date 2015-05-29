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

