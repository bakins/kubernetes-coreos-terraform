#!/bin/bash
set -e
set -x

source /etc/kubernetes.env

mkdir -p /etc/kubernetes/manifests
mkdir -p /srv/kubernetes/manifests

cat <<EOF > /etc/kubernetes/manifests/kube-apiserver.yaml
apiVersion: v1
kind: Pod
metadata:
  name: kube-apiserver
  namespace: kube-system
spec:
  hostNetwork: true
  containers:
  - name: kube-apiserver
    image: gcr.io/google_containers/hyperkube:v${KUBERNETES_VERSION}
    command:
    - /hyperkube
    - apiserver
    # - --insecure-bind-address=0.0.0.0
    - --bind-address=0.0.0.0
    - --etcd-servers=${ETCD_ENDPOINTS}
    - --allow-privileged=true
    - --service-cluster-ip-range=${SERVICE_IP_RANGE}
    - --secure-port=${API_SECURE_PORT}
    # - --insecure-port=8080
    - --advertise-address=${PRIVATE_IP}
    - --admission-control=NamespaceLifecycle,NamespaceExists,LimitRanger,SecurityContextDeny,ServiceAccount,ResourceQuota
    - --tls-cert-file=/etc/kubernetes/ssl/apiserver.pem
    - --tls-private-key-file=/etc/kubernetes/ssl/apiserver-key.pem
    - --client-ca-file=/etc/kubernetes/ssl/ca.pem
    - --service-account-key-file=/etc/kubernetes/ssl/apiserver-key.pem
    # - --token-auth-file=/etc/kubernetes/ssl/tokens.csv
    - --logtostderr=true
    - --cloud-provider=aws
    ports:
    - containerPort: ${API_SECURE_PORT}
      hostPort: ${API_SECURE_PORT}
      name: https
    - containerPort: 8080
      hostPort: 8080
      name: local
    volumeMounts:
    - mountPath: /etc/kubernetes/ssl
      name: ssl-certs-kubernetes
      readOnly: true
    - mountPath: /etc/ssl/certs
      name: ssl-certs-host
      readOnly: true
  volumes:
  - hostPath:
      path: /etc/kubernetes/ssl
    name: ssl-certs-kubernetes
  - hostPath:
      path: /usr/share/ca-certificates
    name: ssl-certs-host
EOF

cat <<EOF > /srv/kubernetes/manifests/kube-controller-manager.yaml
apiVersion: v1
kind: Pod
metadata:
  name: kube-controller-manager
  namespace: kube-system
spec:
  containers:
  - name: kube-controller-manager
    image: gcr.io/google_containers/hyperkube:v${KUBERNETES_VERSION}
    command:
    - /hyperkube
    - controller-manager
    - --master=http://127.0.0.1:8080
    - --service-account-private-key-file=/etc/kubernetes/ssl/apiserver-key.pem
    - --root-ca-file=/etc/kubernetes/ssl/ca.pem
    # - --cluster-name=${CLUSTER_NAME}
    - --cloud-provider=aws
    livenessProbe:
      httpGet:
        host: 127.0.0.1
        path: /healthz
        port: 10252
      initialDelaySeconds: 15
      timeoutSeconds: 1
    volumeMounts:
    - mountPath: /etc/kubernetes/ssl
      name: ssl-certs-kubernetes
      readOnly: true
    - mountPath: /etc/ssl/certs
      name: ssl-certs-host
      readOnly: true
  hostNetwork: true
  volumes:
  - hostPath:
      path: /etc/kubernetes/ssl
    name: ssl-certs-kubernetes
  - hostPath:
      path: /usr/share/ca-certificates
    name: ssl-certs-host
EOF

cat <<EOF > /etc/kubernetes/manifests/kube-podmaster.yaml
apiVersion: v1
kind: Pod
metadata:
  name: kube-podmaster
  namespace: kube-system
spec:
  hostNetwork: true
  containers:
  - name: scheduler-elector
    image: gcr.io/google_containers/podmaster:1.1
    command:
    - /podmaster
    - --etcd-servers=${ETCD_ENDPOINTS}
    - --key=scheduler
    - --whoami=${PRIVATE_IP}
    - --source-file=/src/manifests/kube-scheduler.yaml
    - --dest-file=/dst/manifests/kube-scheduler.yaml
    volumeMounts:
    - mountPath: /src/manifests
      name: manifest-src
      readOnly: true
    - mountPath: /dst/manifests
      name: manifest-dst
  - name: controller-manager-elector
    image: gcr.io/google_containers/podmaster:1.1
    command:
    - /podmaster
    - --etcd-servers=${ETCD_ENDPOINTS}
    - --key=controller
    - --whoami=${PRIVATE_IP}
    - --source-file=/src/manifests/kube-controller-manager.yaml
    - --dest-file=/dst/manifests/kube-controller-manager.yaml
    terminationMessagePath: /dev/termination-log
    volumeMounts:
    - mountPath: /src/manifests
      name: manifest-src
      readOnly: true
    - mountPath: /dst/manifests
      name: manifest-dst
  volumes:
  - hostPath:
      path: /srv/kubernetes/manifests
    name: manifest-src
  - hostPath:
      path: /etc/kubernetes/manifests
    name: manifest-dst
EOF

cat <<EOF > /etc/kubernetes/manifests/kube-proxy.yaml
apiVersion: v1
kind: Pod
metadata:
  name: kube-proxy
  namespace: kube-system
spec:
  hostNetwork: true
  containers:
  - name: kube-proxy
    image: gcr.io/google_containers/hyperkube:v${KUBERNETES_VERSION}
    command:
    - /hyperkube
    - proxy
    - --master=http://127.0.0.1:8080
    - --proxy-mode=iptables
    securityContext:
      privileged: true
    volumeMounts:
    - mountPath: /etc/ssl/certs
      name: ssl-certs-host
      readOnly: true
  volumes:
  - hostPath:
      path: /usr/share/ca-certificates
    name: ssl-certs-host
EOF

cat <<EOF > /srv/kubernetes/manifests/kube-scheduler.yaml
apiVersion: v1
kind: Pod
metadata:
  name: kube-scheduler
  namespace: kube-system
spec:
  hostNetwork: true
  containers:
  - name: kube-scheduler
    image: gcr.io/google_containers/hyperkube:v${KUBERNETES_VERSION}
    command:
    - /hyperkube
    - scheduler
    - --master=http://127.0.0.1:8080
    # - --logtostderr=true
    livenessProbe:
      httpGet:
        host: 127.0.0.1
        path: /healthz
        port: 10251
      initialDelaySeconds: 15
      timeoutSeconds: 1
EOF
