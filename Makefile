# Build the docs site with md-preview, in folder mode.
#
#   make              build docs/ into _site/
#   make fetch        download KaTeX and mermaid once, to self-host them
#   make check        fail if a page still links to a .md file
#   make serve        build, then preview _site/ at http://localhost:8000
#   make clean        remove _site/ and _build/
#
# SITE_URL is where the site is published (with a trailing slash). When set,
# md-preview also writes _site/sitemap.xml, dated from git history.

MDP      ?= md-preview
SRC      := docs
OUT      := _site
BUILD    := _build
SITE_URL ?=

BASE_URL := $(if $(SITE_URL),--base-url $(SITE_URL))

.DEFAULT_GOAL := site
.PHONY: site fetch check serve clean

# Keep md-preview's build state out of _site/, so it isn't published.
site:
	MD_PREVIEW_STATE=$(abspath $(BUILD))/state $(MDP) build $(SRC) -o $(OUT) $(BASE_URL)

# Idempotent: skips what is already downloaded.
fetch:
	@$(MDP) fetch

# md-preview rewrites links between pages to .html; a relative link that is
# still .md points outside docs/ and is broken on the published site.
check:
	@if grep -rnoE 'href="[^":#]*\.md(#[^"]*)?"' --include='*.html' $(OUT); then \
	  echo "error: links to .md files above are broken once published" >&2; exit 1; \
	else echo "links ok"; fi

serve: site
	python3 -m http.server --directory $(OUT) 8000

clean:
	rm -rf $(OUT) $(BUILD)
