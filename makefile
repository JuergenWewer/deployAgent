IMAGE_NAME = ergo-gitops-deployer
GITOPS-REPO = ergo-devops-local-minishift
GITOPS-REPO-DIR = ~/gitops-test/
KUSTOMIZE-DIR = ~/Downloads

.PHONY: build rebuild deploy lint

lint:
	@shellcheck deployer library
	@shellcheck validation-service/validation library
	@hadolint --ignore DL3007 --ignore DL3008 ./Dockerfile 

build:
	docker build -t $(IMAGE_NAME) .

test-image:
	docker run --rm -it --entrypoint=/bin/bash ergo-gitops-deployer

rebuild:
	docker build --no-cache -t $(IMAGE_NAME) .

deploy:
	docker tag $(IMAGE_NAME):latest hub.itgo-devops.org:18443/oscp/$(IMAGE_NAME):latest
	docker push hub.itgo-devops.org:18443/oscp/$(IMAGE_NAME):latest

test: lint build clone-gitops-repo minishift-start minishift-prepare minishift-end

minishift-start:
	minishift start --memory 16384 --cpus 4

minishift-prepare:
	oc new-project ergo-devops

minishift-secret:
	oc project ergo-devops
	# oc create secret generic gitops-deployer-secret --from-literal=GITOPS_USER=${GITOPS_USER} --from-literal=GITOPS_TOKEN=${GITOPS_TOKEN} 

minishift-login-registry:
	@# run this command once in the outer shell
	@echo '*****************************************************************************************************'
	@echo '*** Please run eval $$(minishift docker-env) ONCE in your outer shell. And then repeat this step. ***'
	@echo '*****************************************************************************************************'

	@eval $(shell minishift docker-env)
	@docker login -u $(shell oc whoami) -p $(shell oc whoami -t) $(shell minishift openshift registry)

minishift-build-image:
	docker build -t $(IMAGE_NAME) .

minishift-deploy-nexus-image:
	docker pull hub.itgo-devops.org:18443/oscp/ergo-gitops-deployer:latest
	docker tag hub.itgo-devops.org:18443/oscp/ergo-gitops-deployer:latest $(shell minishift openshift registry)/ergo-devops/$(IMAGE_NAME)
	docker push $(shell minishift openshift registry)/ergo-devops/$(IMAGE_NAME)

minishift-deploy:
	docker tag $(IMAGE_NAME) $(shell minishift openshift registry)/ergo-devops/$(IMAGE_NAME)
	docker push $(shell minishift openshift registry)/ergo-devops/$(IMAGE_NAME)

gitops-clone:
	rm -rf ${GITOPS-REPO-DIR}
	git clone https://github.itergo.com/ERGO-GitOps/${GITOPS-REPO}.git ${GITOPS-REPO-DIR}
	cd ${GITOPS-REPO-DIR}; bash ./decrypt.sh

gitops-create-branch:
	cd ${GITOPS-REPO-DIR}; git checkout -b make-branch
	cd ${GITOPS-REPO-DIR}; git push --set-upstream origin make-branch

gitops-create-pr:
	cd ${GITOPS-REPO-DIR}; gh pr create --title "A testing pr" -f

gitops-close-pr:
	cd ${GITOPS-REPO-DIR}; gh pr merge -s

gitops-update:
	$(eval IMAGE := $(shell docker inspect --format='{{index .RepoDigests 0}}' $(shell minishift openshift registry)/ergo-devops/ergo-gitops-deployer))
	cd ${GITOPS-REPO-DIR}overlays/gitops/gitops-validation-test; \
	  kustomize edit set image gitops-validation=$(IMAGE)

	cd ${GITOPS-REPO-DIR}overlays/gitops/gitops-deployer-test ; \
	  kustomize edit set image gitops-deployer=$(IMAGE)

	# Force change : add minimal change
	cd ${GITOPS-REPO-DIR}; echo " " >> ./overlays/deploy/kustomization.yaml

gitops-commit:
	cd ${GITOPS-REPO-DIR}; \
	  git commit -am 'Automatic update' && \
	  git push

gitops-apply:
	${KUSTOMIZE-DIR}/kustomize version
	${KUSTOMIZE-DIR}/kustomize build ${GITOPS-REPO-DIR}overlays/deploy | oc apply -f -

minishift-bootstrap: minishift-start minishift-prepare minishift-secret minishift-login-registry
minishift-ci:  minishift-build-image minishift-deploy

minishift-cd-nexus: minishift-deploy-nexus-image gitops-clone gitops-update gitops-commit gitops-apply
minishift-cd: gitops-clone gitops-update gitops-commit
minishift-cd-pr: gitops-clone gitops-create-branch gitops-update gitops-commit gitops-create-pr
minishift-cd-initial: gitops-clone gitops-update gitops-commit gitops-apply

minishift-ci-cd: minishift-ci minishift-cd
minishift-ci-cd-initial: minishift-ci minishift-cd-initial

minishift-end:
	minishift stop
	minishift delete -f
