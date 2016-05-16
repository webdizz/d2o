#!/usr/bin/env bash

# Prepare, configure and start OpenShift

set -o pipefail
set -o nounset

export GOFABRIC8_VERSION="0.4.27"
export OPENSHIFT_VERSION="1.2.0"
export OPENSHIFT_VERSION_CS="2e62fab"
export ORIGIN_DIR="/opt/openshift-${OPENSHIFT_VERSION}"
export OPENSHIFT_DIR=${ORIGIN_DIR}/openshift.local.config/master
export KUBECONFIG=${OPENSHIFT_DIR}/admin.kubeconfig

# setup openshift
if [ -d "${ORIGIN_DIR}" ]; then
  echo "==> OpenShift v${OPENSHIFT_VERSION} installed"
else
  echo "==> Installation of OpenShift v${OPENSHIFT_VERSION}"
  mkdir /tmp/openshift
  echo "https://github.com/openshift/origin/releases/download/v${OPENSHIFT_VERSION}/openshift-origin-server-v${OPENSHIFT_VERSION}-${OPENSHIFT_VERSION_CS}-linux-64bit.tar.gz"
  echo "Downloading OpenShift binaries..."
  curl -k --retry 999 --retry-max-time 0  -sSL "https://github.com/openshift/origin/releases/download/v${OPENSHIFT_VERSION}/openshift-origin-server-v${OPENSHIFT_VERSION}-${OPENSHIFT_VERSION_CS}-linux-64bit.tar.gz" | tar xzv -C /tmp/openshift
  rm -rf /tmp/openshift/openshift-origin-*/LICENSE
  rm -rf /tmp/openshift/openshift-origin-*/README.md
  mkdir -p "${ORIGIN_DIR}/openshift.local.manifests" /var/lib/openshift
  mv /tmp/openshift/openshift-origin-*/* "${ORIGIN_DIR}/"

  echo "Prepare OpenShift env variables"
  echo "export OPENSHIFT=${ORIGIN_DIR}"  > /etc/profile.d/openshift.sh
  echo "export OPENSHIFT_VERSION=v${OPENSHIFT_VERSION}"  >> /etc/profile.d/openshift.sh
  echo "export PATH=${ORIGIN_DIR}:$PATH"  >> /etc/profile.d/openshift.sh
  echo "export KUBECONFIG=${OPENSHIFT_DIR}/admin.kubeconfig"  >> /etc/profile.d/openshift.sh
  echo "export CURL_CA_BUNDLE=${OPENSHIFT_DIR}/ca.crt"  >> /etc/profile.d/openshift.sh
  chmod 755 /etc/profile.d/openshift.sh

  echo "Pull OpenShift Docker images for v$OPENSHIFT_VERSION"
  systemctl restart docker
  docker pull openshift/origin-pod:v$OPENSHIFT_VERSION
  docker pull openshift/origin-sti-builder:v$OPENSHIFT_VERSION
  docker pull openshift/origin-docker-builder:v$OPENSHIFT_VERSION
  docker pull openshift/origin-deployer:v$OPENSHIFT_VERSION
  docker pull openshift/origin-docker-registry:v$OPENSHIFT_VERSION
  docker pull openshift/origin-haproxy-router:v$OPENSHIFT_VERSION

  echo "Add firewall rules"
  firewall-cmd --permanent --zone=public --add-port=80/tcp
  firewall-cmd --permanent --zone=public --add-port=443/tcp
  firewall-cmd --permanent --zone=public --add-port=8443/tcp
  firewall-cmd --reload
fi

if [ -f "$ORIGIN_DIR/gofabric8" ]; then
  echo "==> gofabric8 v${GOFABRIC8_VERSION} installed"
else
  echo "==> Installation of gofabric8 v${GOFABRIC8_VERSION}"
  # download gofabric8
  mkdir /tmp/gofabric8
  curl -k -retry 999 --retry-max-time 0  -sSL "https://github.com/fabric8io/gofabric8/releases/download/v${GOFABRIC8_VERSION}/gofabric8-${GOFABRIC8_VERSION}-linux-amd64.tar.gz" | tar xzv -C /tmp/gofabric8
  chmod +x /tmp/gofabric8/gofabric8
  mv /tmp/gofabric8/gofabric8 "${ORIGIN_DIR}/"
fi

if [ -d "/vagrant" ]; then
  if [ -f "${ORIGIN_DIR}/.os_configured" ]; then
    echo "==> OpenShift v${OPENSHIFT_VERSION} configured"
  else
    echo '192.168.33.77   d2o.vgnt' >> /etc/hosts
    echo "==> OpenShift v${OPENSHIFT_VERSION} configuration"
    . /etc/profile.d/openshift.sh

    echo "Create certificates"
    oadm ca create-master-certs \
     --hostnames=d2o.vgnt \
     --public-master=https://192.168.33.77:8443 \
     --overwrite=true \
     --cert-dir="${ORIGIN_DIR}/openshift.local.config/master"

    ${ORIGIN_DIR}/openshift start  --write-config="${ORIGIN_DIR}/openshift.local.config" \
      --master=192.168.33.77  \
      --cors-allowed-origins=.* \
      --dns='tcp://192.168.33.77:53' \
      --create-certs=true

    chmod +r $OPENSHIFT_DIR/admin.kubeconfig
    chmod +r $OPENSHIFT_DIR/openshift-registry.kubeconfig
    chmod +r $OPENSHIFT_DIR/openshift-router.kubeconfig
    sed -i 's/router.default.svc.cluster.local/d2o.vgnt/' $OPENSHIFT_DIR/master-config.yaml

    echo "Create OpenShift service"
    cat > /etc/systemd/system/openshift-origin.service << '__EOF__'
[Unit]
Description=Origin Master Service
After=docker.service
Requires=docker.service

[Service]
Restart=always
RestartSec=10s
ExecStart=openshift_path/openshift start --master=192.168.33.77 --cors-allowed-origins=.* --dns='tcp://192.168.33.77:53'
WorkingDirectory=openshift_path

[Install]
WantedBy=multi-user.target
__EOF__

    sed -i "s|openshift_path|$OPENSHIFT|g" /etc/systemd/system/openshift-origin.service
    systemctl daemon-reload
    systemctl enable openshift-origin
    systemctl start openshift-origin

    echo "Wait until OpenShift start"
    until curl -k -s -f  --connect-timeout 1 https://192.168.33.77:8443/healthz/ready | grep ok; do sleep 10 ; done

    ${OPENSHIFT}/oadm policy add-cluster-role-to-user cluster-admin admin
    gofabric8 deploy -y --domain=d2o.vgnt -s https://192.168.33.77:8443
    mkdir -p /home/vagrant/.kube/
    ln -s ${ORIGIN_DIR}/master/admin.kubeconfig /home/vagrant/.kube/config
    chown -R vagrant:vagrant /home/vagrant/.kube/
    until oc get pods -l project=console,provider=fabric8  | grep -m 1 "Running"; do sleep 1 ; done

    echo "Fabric8 console is now running. Waiting for the Openshift Router to start..."
    ${OPENSHIFT}/oadm router --create --service-account=router --expose-metrics
    until oc get pods -l deploymentconfig=router,router=router  | grep -m 1 "Running"; do sleep 1 ; done
    oc annotate service router prometheus.io/port=9101
    oc annotate service router prometheus.io/scheme=http
    oc annotate service router prometheus.io/path=/metrics
    oc annotate service router prometheus.io/scrape=true

    echo "Waiting for the Openshift Registry to start..."
    oc create serviceaccount registry
    ${OPENSHIFT}/oadm registry --create  --service-account=registry
    until oc get pods -l deploymentconfig=docker-registry,docker-registry=default  | grep -m 1 "Running"; do sleep 1 ; done
    oc create -f /vagrant/openshift/route/docker-registry.yaml

    chown -R vagrant:vagrant /opt/openshift-1.2.0
    gofabric8 pull cd-pipeline
   fi
fi
