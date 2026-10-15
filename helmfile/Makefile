# Run helmfile against the lab's k3s, with ~/.kube/config.
#
#   make -C helmfile diff     what would change
#   make -C helmfile apply    change it, only what differs
#   make -C helmfile lint     render every release, without the cluster
#
# Secrets are decrypted by helm-secrets with the laptop's age key.

HELMFILE := helmfile -f helmfile.yaml.gotmpl

.PHONY: diff apply lint

diff:
	$(HELMFILE) diff --context 3

apply:
	$(HELMFILE) apply

lint:
	$(HELMFILE) lint
