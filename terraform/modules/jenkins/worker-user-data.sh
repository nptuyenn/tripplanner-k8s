#!/usr/bin/env bash
set -euxo pipefail

exec > >(tee /var/log/tripplanner-user-data.log | logger -t user-data -s 2>/dev/console) 2>&1

dnf update -y
dnf install -y \
  docker \
  git \
  gzip \
  java-21-amazon-corretto-headless \
  jq \
  tar \
  unzip \
  xz

systemctl enable --now docker
usermod -aG docker ec2-user

if ! command -v aws >/dev/null 2>&1; then
  curl -fsSLo /tmp/awscliv2.zip https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip
  unzip -q /tmp/awscliv2.zip -d /tmp
  /tmp/aws/install
  rm -rf /tmp/aws /tmp/awscliv2.zip
fi

curl -fsSLo /usr/local/bin/kubectl https://dl.k8s.io/release/v1.35.4/bin/linux/amd64/kubectl
chmod 0755 /usr/local/bin/kubectl

NODE_VERSION="v22.17.0"
curl -fsSLo /tmp/node.tar.xz "https://nodejs.org/dist/${NODE_VERSION}/node-${NODE_VERSION}-linux-x64.tar.xz"
tar -xJf /tmp/node.tar.xz -C /usr/local --strip-components=1
rm -f /tmp/node.tar.xz

cat >/etc/yum.repos.d/trivy.repo <<'EOF'
[trivy]
name=Trivy repository
baseurl=https://aquasecurity.github.io/trivy-repo/rpm/releases/$basearch/
enabled=1
gpgcheck=0
EOF

dnf install -y trivy
