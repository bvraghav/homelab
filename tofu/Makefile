# Run OpenTofu with the state passphrase from SOPS.
#
#   make -C tofu init     download the pinned providers
#   make -C tofu plan     show what would change
#   make -C tofu apply    apply the saved plan, then stage the state for git
#   make -C tofu check    fail unless the state file is encrypted
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
