FROM registry.access.redhat.com/ubi8-minimal:latest
USER root

LABEL maintainer="Marius Filipowski <marius.filipowski@itergo.com>" \
      io.k8s.description="Image for simple GitOps approach." \
      io.k8s.display-name="GitOps-Simple-Deployer"

ENV KUBECTL_VERSION=v1.20.1 \
    JQ_VERSION=1.6 \
    HUB_VERSION=2.14.2 \
    KUBEVAL_VERSION=0.15.0 \
    KUSTOMIZE_VERSION=3.8.8 \
    GH_CLI_VERSION=1.4.0 \
    SOPS_VERSION=v3.6.1 \
    HOME=/home

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

RUN microdnf update && \
    microdnf install git tar && \
    curl -LO -O https://github.com/stedolan/jq/releases/download/jq-${JQ_VERSION}/jq-linux64 && \
    chmod +x ./jq-linux64  && \
    mv jq-linux64 /usr/local/bin/jq  && \
    curl -LO -O https://github.com/mozilla/sops/releases/download/${SOPS_VERSION}/sops-${SOPS_VERSION}.linux && \
    chmod +x ./sops-${SOPS_VERSION}.linux  && \
    mv ./sops-${SOPS_VERSION}.linux /usr/local/bin/sops  && \
    curl -LO https://storage.googleapis.com/kubernetes-release/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl && \
    chmod +x ./kubectl && \
    mv ./kubectl /usr/local/bin/kubectl && \
    curl -L https://github.com/kubernetes-sigs/kustomize/releases/download/kustomize%2Fv${KUSTOMIZE_VERSION}/kustomize_v${KUSTOMIZE_VERSION}_linux_amd64.tar.gz | tar zxv -C /var/tmp && \
    chmod +x /var/tmp/kustomize && \
    mv /var/tmp/kustomize /usr/local/bin/kustomize && \
    curl -L https://github.com/instrumenta/kubeval/releases/download/${KUBEVAL_VERSION}/kubeval-linux-amd64.tar.gz | tar zxv -C /var/tmp  && \
    mv /var/tmp/kubeval /usr/local/bin/kubeval && \
    curl -L https://github.com/cli/cli/releases/download/v${GH_CLI_VERSION}/gh_${GH_CLI_VERSION}_linux_amd64.tar.gz | tar zxv -C /var/tmp  && \
    mv /var/tmp/gh_${GH_CLI_VERSION}_linux_amd64/bin/gh /usr/local/bin/gh && rm -rf /var/tmp/gh_${GH_CLI_VERSION}_linux_amd64 && \
    curl -L https://github.com/github/hub/releases/download/v${HUB_VERSION}/hub-linux-amd64-${HUB_VERSION}.tgz | tar zxv -C /var/tmp && \
    mv /var/tmp/hub-linux-amd64-${HUB_VERSION}/bin/hub /usr/local/bin/hub && rm -rf /var/tmp/hub-linux-amd64-${HUB_VERSION} && \
    microdnf clean all

COPY library deployer validation-service/validation /opt/app-root/ 

# allow caching for kubectl in .kube dir
RUN chmod a+rwx ${HOME} && \
    mkdir ${HOME}/.kube && \
    chmod a+rw ${HOME}/.kube && \
    mkdir ${HOME}/.gnupg && \
    chmod a+rw ${HOME}/.gnupg

USER 1001

ENTRYPOINT [ "/bin/bash" ]
CMD [ "/opt/app-root/deployer" ]