#! /bin/bash

# Preload docker images used in the workshop (run this first so Katacoda has time to provision Kube)
docker pull docker.io/ibmcom/portieris:0.5.1
docker pull goharbor/harbor-adminserver:v1.7.0
docker pull goharbor/clair-photon:v2.0.7-v1.7.0
docker pull goharbor/harbor-core:v1.7.0
docker pull goharbor/harbor-jobservice:v1.7.0
docker pull goharbor/nginx-photon:v1.7.0
docker pull goharbor/notary-server-photon:v0.6.1-v1.7.0
docker pull goharbor/notary-signer-photon:v0.6.1-v1.7.0
docker pull goharbor/harbor-portal:v1.7.0
docker pull goharbor/registry-photon:v2.6.2-v1.7.0
docker pull goharbor/harbor-registryctl:v1.7.0
docker pull goharbor/harbor-db:v1.7.0
docker pull goharbor/redis-photon:v1.7.0
docker pull sublimino/alpine-base:insecure
docker pull alpine:3.4

# Make Clair database deploy script executable (Katacoda doesn't preserve file permissions)
chmod a+x deploy_db.sh

# Pull down a Clair DB so we can push it into the container later and don't need to wait for it to autoupdate
curl -O https://raw.githubusercontent.com/s-irvine/katacoda-test/master/kube-sec-deploy/assets/clair-db/clear.sql &&
curl -O https://raw.githubusercontent.com/s-irvine/katacoda-test/master/kube-sec-deploy/assets/clair-db/vulnerability.sql &&
echo "Clair DB Downloaded" &&

# Wait for Kubernetes to be up
echo -n "Waiting for Kubernetes to be ready to use" &&
until kubectl get pod 2>/dev/null ; do echo -n . ; sleep 1 ; done ; echo &&
echo "Ready to go!"
