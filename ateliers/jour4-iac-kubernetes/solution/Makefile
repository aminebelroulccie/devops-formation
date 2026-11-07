# Formation DevOps Formini — Jour 4
# make tf-up / make ansible / make tf-down / make k8s-up / make k8s-down
SHELL := /bin/bash
TF    := terraform -chdir=terraform
NS    := formini-tasks

.PHONY: help tf-init tf-plan tf-up tf-down ansible-ping ansible k8s-up k8s-status k8s-down

help:
	@grep -E '^[a-z-]+:.*## ' $(MAKEFILE_LIST) | awk -F':.*## ' '{printf "  %-14s %s\n", $$1, $$2}'

tf-init:        ## terraform init + validate
	$(TF) init && $(TF) validate

tf-plan: tf-init ## lire le plan
	$(TF) plan

tf-up: tf-init  ## créer le serveur AWS
	$(TF) apply
	$(TF) output

tf-down:        ## DÉTRUIRE le serveur AWS (obligatoire avant 16:00)
	$(TF) destroy

ansible-ping:   ## la cible répond-elle ?
	cd ansible && ansible web -m ping

ansible:        ## installer Docker et lancer l'application
	cd ansible && ansible-playbook playbook.yml

k8s-up:         ## cluster kind + déploiement
	./deploy.sh

k8s-status:     ## état du namespace
	kubectl -n $(NS) get all,pvc

k8s-down:       ## supprimer le cluster kind
	kind delete cluster --name formini
