#!/usr/bin/env bash
set -euxo pipefail

exec > >(tee /var/log/tripplanner-user-data.log | logger -t user-data -s 2>/dev/console) 2>&1

dnf update -y
dnf install -y \
  curl \
  docker \
  dnf-plugins-core \
  git \
  gzip \
  java-21-amazon-corretto-headless \
  jq \
  tar \
  unzip

systemctl enable --now docker
usermod -aG docker ec2-user

if ! command -v aws >/dev/null 2>&1; then
  curl -fsSLo /tmp/awscliv2.zip https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip
  unzip -q /tmp/awscliv2.zip -d /tmp
  /tmp/aws/install
  rm -rf /tmp/aws /tmp/awscliv2.zip
fi

dnf config-manager --add-repo https://rpm.releases.hashicorp.com/AmazonLinux/hashicorp.repo
dnf install -y terraform

curl -fsSLo /usr/local/bin/kubectl https://dl.k8s.io/release/v1.35.4/bin/linux/amd64/kubectl
chmod 0755 /usr/local/bin/kubectl

HELM_VERSION="v3.18.4"
curl -fsSLo /tmp/helm.tar.gz "https://get.helm.sh/helm-${HELM_VERSION}-linux-amd64.tar.gz"
tar -xzf /tmp/helm.tar.gz -C /tmp
install -m 0755 /tmp/linux-amd64/helm /usr/local/bin/helm
rm -rf /tmp/helm.tar.gz /tmp/linux-amd64

