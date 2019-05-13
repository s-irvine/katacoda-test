#! /bin/bash

# Preload docker images used in the workshop (run this first so Katacoda has time to provision Kube)
docker pull docker.io/ibmcom/portieris:0.5.1
docker pull goharbor/harbor-adminserver:dev
docker pull goharbor/clair-photon:dev
docker pull goharbor/harbor-core:dev
docker pull goharbor/harbor-jobservice:dev
docker pull goharbor/nginx-photon:dev
docker pull goharbor/notary-server-photon:dev
docker pull goharbor/notary-signer-photon:dev
docker pull goharbor/harbor-portal:dev
docker pull goharbor/registry-photon:dev
docker pull goharbor/harbor-registryctl:dev
docker pull goharbor/harbor-db:dev
docker pull goharbor/redis-photon:dev

# Update docker (so we have a version with `docker trust` commands)
systemctl stop kubelet
cp /lib/systemd/system/docker.service .
apt-get remove -y docker docker-engine docker.io containerd runc &&
rm /etc/systemd/system/docker.service /etc/systemd/system/docker.socket &&
systemctl daemon-reload &&
apt-get update &&
apt-get install -y \
        apt-transport-https \
        ca-certificates \
        curl \
        gnupg-agent \
        software-properties-common &&
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add - &&
add-apt-repository \
    "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
    $(lsb_release -cs) \
    stable" &&
apt-get update #&&
mv /etc/docker/daemon.json /etc/docker/daemon-old.json &&
mv daemon.json /etc/docker/daemon.json &&
apt-get install -y docker-ce docker-ce-cli containerd.io  || true &&
mv /etc/docker/daemon-old.json /etc/docker/daemon.json &&
# Remove '-H fd://' from the command invocation of the docker service as it conflicts with the `daemon.json`
sed 's/\ \-H\ fd\:\/\///g' /lib/systemd/system/docker.service > /lib/systemd/system/docker.service &&
cat /etc/docker/daemon.json | jq '.["insecure-registries"] += ["127.0.0.1/8"]' > /etc/docker/daemon.json &&
systemctl daemon-reload &&
systemctl start docker &&
systemctl start kubelet

# Pull down a Clair DB and push it into the container so we don't need to wait for it to update
