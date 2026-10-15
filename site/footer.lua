-- footer.lua: a pandoc filter that adds a footer to every page of the docs
-- site, with the site version and, when known, links to the page's source
-- and the commit it was built from.
--
-- Metadata it reads (passed with -M by the Makefile):
--   homelab-version   version shown in the footer (required)
--   homelab-ref       commit the site is built from
--   homelab-repo      repository URL, e.g. https://github.com/<owner>/<repo>
--   md-preview-page   set by md-preview: the page's source relative to docs/,
--                     or "dir/" for a generated folder listing

local stringify = pandoc.utils.stringify

local function meta(doc, key)
  local v = doc.meta[key]
  if v == nil then return nil end
  local s = stringify(v)
  if s == '' then return nil end
  return s
end

local function esc(s)
  return (s:gsub('&', '&amp;'):gsub('<', '&lt;'):gsub('>', '&gt;'):gsub('"', '&quot;'))
end

function Pandoc(doc)
  local version = meta(doc, 'homelab-version')
  if not version then return doc end
  local ref = meta(doc, 'homelab-ref')
  local repo = meta(doc, 'homelab-repo')
  local page = meta(doc, 'md-preview-page')

  local parts = { string.format('homelab docs <strong>%s</strong>', esc(version)) }

  if page and not page:match('/$') then
    local source = 'docs/' .. page
    if repo and ref then
      table.insert(parts, string.format('source <a href="%s/blob/%s/%s"><code>%s</code></a>',
        esc(repo), esc(ref), esc(source), esc(source)))
    else
      table.insert(parts, string.format('source <code>%s</code>', esc(source)))
    end
  end

  if ref then
    local short = ref:sub(1, 7)
    if repo then
      table.insert(parts, string.format('commit <a href="%s/commit/%s"><code>%s</code></a>',
        esc(repo), esc(ref), esc(short)))
    else
      table.insert(parts, string.format('commit <code>%s</code>', esc(short)))
    end
  end

  doc.blocks:insert(pandoc.RawBlock('html',
    '<footer class="site-footer" style="margin-top:4rem;padding-top:1rem;'
      .. 'border-top:1px solid var(--border);color:var(--muted);font-size:0.85rem">'
      .. table.concat(parts, ' · ') .. '</footer>'))
  return doc
end
