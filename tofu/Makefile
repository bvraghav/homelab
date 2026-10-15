# Run OpenTofu with the state passphrase from SOPS.
#
#   make -C tofu init     download the pinned providers
#   make -C tofu plan     show what would change
#   make -C tofu apply    apply the saved plan, then stage the state for git
#   make -C tofu check    fail unless the state file is encrypted
#
# To pass options to plan, use OpenTofu's TF_CLI_ARGS_plan, e.g. to
# rebuild a VM from scratch:
#   TF_CLI_ARGS_plan='-replace=proxmox_virtual_environment_vm.vm[\"pihole\"]' make -C tofu plan
# (OpenTofu splits it like a shell would, so the inner quotes are escaped.)
#
# The state (terraform.tfstate) is committed, encrypted. After an apply,
# commit it: git commit -m "..." tofu/terraform.tfstate
# Uploading snippets needs SSH to the host as root, with the key loaded in
# ssh-agent (ssh-add).

SECRETS := ../secrets/tofu.sops.yaml
TOFU    := sops exec-env $(SECRETS)
STATE   := terraform.tfstate
PLAN    := tofu.tfplan

.PHONY: init plan apply check

init:
	$(TOFU) 'tofu init'

plan:
	$(TOFU) 'tofu plan -out=$(PLAN)'

apply:
	@test -f $(PLAN) || { echo "no saved plan: run make plan first" >&2; exit 1; }
	$(TOFU) 'tofu apply $(PLAN)'
	rm -f $(PLAN)
	$(MAKE) check
	git add $(STATE)

# An encrypted state has encrypted_data and nothing readable besides.
check:
	@jq -e 'has("encrypted_data") and (has("resources") | not)' $(STATE) >/dev/null \
	  && echo "state is encrypted" \
	  || { echo "error: $(STATE) is not encrypted; don't commit it" >&2; exit 1; }
