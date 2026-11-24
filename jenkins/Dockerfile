# Jenkins controller with every CLI the pipelines need (Docker outside of Docker via the host socket).
FROM jenkins/jenkins:lts-jdk21

# hadolint ignore=DL3066
USER root
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# hadolint ignore=DL3008
RUN apt-get update && apt-get install -y --no-install-recommends \
      ca-certificates curl gnupg jq unzip git openssh-client python3 python3-pip python3-venv \
 && install -m 0755 -d /etc/apt/keyrings \
 && curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc \
 && . /etc/os-release \
 && echo "deb [signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian ${VERSION_CODENAME} stable" \
      > /etc/apt/sources.list.d/docker.list \
 && apt-get update && apt-get install -y --no-install-recommends docker-ce-cli docker-compose-plugin docker-buildx-plugin \
 && rm -rf /var/lib/apt/lists/*

# kubectl, kustomize, helm, terraform, aws cli, hey, hadolint
# hadolint ignore=DL3003
RUN curl -fsSLo /usr/local/bin/kubectl "https://dl.k8s.io/release/$(curl -Ls https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" \
 && chmod +x /usr/local/bin/kubectl \
 && cd /tmp && curl -s "https://raw.githubusercontent.com/kubernetes-sigs/kustomize/master/hack/install_kustomize.sh" | bash \
 && mv /tmp/kustomize /usr/local/bin/ \
 && curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash \
 && TF=$(curl -s https://checkpoint-api.hashicorp.com/v1/check/terraform | jq -r .current_version) \
 && curl -fsSLo /tmp/tf.zip "https://releases.hashicorp.com/terraform/${TF}/terraform_${TF}_linux_amd64.zip" \
 && unzip -q /tmp/tf.zip -d /usr/local/bin && rm /tmp/tf.zip \
 && curl -fsSLo /tmp/awscli.zip https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip \
 && unzip -q /tmp/awscli.zip -d /tmp && /tmp/aws/install && rm -rf /tmp/aws /tmp/awscli.zip \
 && curl -fsSLo /usr/local/bin/hey https://hey-release.s3.us-east-2.amazonaws.com/hey_linux_amd64 \
 && curl -fsSLo /usr/local/bin/hadolint https://github.com/hadolint/hadolint/releases/latest/download/hadolint-Linux-x86_64 \
 && chmod +x /usr/local/bin/hey /usr/local/bin/hadolint

# Ansible in its own virtualenv (+ kubernetes client for kubernetes.core modules)
ENV PATH="/opt/ansible/bin:${PATH}"
RUN python3 -m venv /opt/ansible \
 && /opt/ansible/bin/pip install --no-cache-dir ansible kubernetes \
 && /opt/ansible/bin/ansible-galaxy collection install kubernetes.core -p /usr/share/ansible/collections

# hadolint ignore=DL3066
USER jenkins

# Plugins and Configuration as Code (jobs, credentials, admin user)
COPY --chown=jenkins:jenkins plugins.txt /usr/share/jenkins/ref/plugins.txt
RUN jenkins-plugin-cli --plugin-file /usr/share/jenkins/ref/plugins.txt
COPY --chown=jenkins:jenkins casc/ /usr/share/jenkins/ref/casc/
ENV CASC_JENKINS_CONFIG=/usr/share/jenkins/ref/casc \
    JAVA_OPTS="-Djenkins.install.runSetupWizard=false"
