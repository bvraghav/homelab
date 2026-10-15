-- site.lua: a pandoc filter for the docs site. It runs before md-preview's
-- own filter, so it sees links as written in the Markdown.
--
-- 1. Mounted folders. docs/ can include folders from elsewhere in the
--    repository through symlinks (docs/scripts -> ../scripts). Their pages
--    are written for their real location, so their relative links are
--    resolved from there: links into docs/ are rewritten relative to the
--    page's place on the site, and links to other repository files become
--    links to the repository (when homelab-repo is set).
-- 2. Footer. Every page gets a footer with the site version and, when
--    known, links to the page's source and the commit it was built from.
--
-- Metadata it reads (passed with -M by the Makefile):
--   homelab-version   version shown in the footer (required for the footer)
--   homelab-ref       commit the site is built from
--   homelab-repo      repository URL, e.g. https://github.com/<owner>/<repo>
--   md-preview-page   set by md-preview: the page's source relative to docs/,
--                     or "dir/" for a generated folder listing

-- Symlinked folders under docs/: site path → repository path. Add a line
-- here when adding a symlink.
local MOUNTS = {
  ['scripts/'] = 'scripts/',
}

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

-- Path helpers. Paths are relative and use "/"; a trailing "/" marks a folder.

local function split(path)
  local parts = {}
  for part in path:gmatch('[^/]+') do parts[#parts + 1] = part end
  return parts
end

local function dirname(path)
  return path:match('^(.*/)') or ''
end

-- Resolve "." and ".." in path; nil if it climbs above the top.
local function normalize(path)
  local out = {}
  for _, part in ipairs(split(path)) do
    if part == '..' then
      if #out == 0 then return nil end
      out[#out] = nil
    elseif part ~= '.' then
      out[#out + 1] = part
    end
  end
  local result = table.concat(out, '/')
  if path:sub(-1) == '/' and result ~= '' then result = result .. '/' end
  return result
end

-- Relative path from folder `from` (ending in "/" or empty) to `to`.
local function relative(from, to)
  local f, t = split(from), split(to)
  local i = 1
  while i <= #f and i < #t and f[i] == t[i] do i = i + 1 end
  local parts = {}
  for _ = i, #f do parts[#parts + 1] = '..' end
  for j = i, #t do parts[#parts + 1] = t[j] end
  local result = table.concat(parts, '/')
  if to:sub(-1) == '/' then result = result .. '/' end
  return result
end

-- The page's site path (relative to docs/) → its repository path, and the
-- mount it sits in, if any.
local function repo_path(page)
  for site, repo in pairs(MOUNTS) do
    if page:sub(1, #site) == site then return repo .. page:sub(#site + 1), site end
  end
  return 'docs/' .. page, nil
end

-- A repository path → its site path (relative to docs/), or nil if it isn't
-- published.
local function site_path(path)
  if path:sub(1, 5) == 'docs/' then return path:sub(6) end
  for site, repo in pairs(MOUNTS) do
    if path:sub(1, #repo) == repo then return site .. path:sub(#repo + 1) end
  end
  return nil
end

local function rewrite(target, page, repo, ref)
  if target == '' or target:match('^#') or target:match('^/') or target:match('^%a[%w+.-]*:') then
    return nil  -- fragment, absolute path or URL
  end
  local path, frag = target:match('^([^#]*)(#?.*)$')
  local from = repo_path(page)
  local resolved = normalize(dirname(from) .. path)
  if not resolved then return nil end
  local site = site_path(resolved)
  if site then return relative(dirname(page), site) .. frag end
  if repo and ref then return string.format('%s/blob/%s/%s%s', repo, ref, resolved, frag) end
  -- No repository URL (a local build): point at the file on disk, outside
  -- docs/. md-preview leaves such links alone, and `make check` flags them.
  return relative('docs/' .. dirname(page), resolved) .. frag
end

local function footer(version, page, repo, ref)
  local parts = { string.format('homelab docs <strong>%s</strong>', esc(version)) }

  if page and not page:match('/$') then
    local source = repo_path(page)
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

  return pandoc.RawBlock('html',
    '<footer class="site-footer" style="margin-top:4rem;padding-top:1rem;'
      .. 'border-top:1px solid var(--border);color:var(--muted);font-size:0.85rem">'
      .. table.concat(parts, ' · ') .. '</footer>')
end

function Pandoc(doc)
  local version = meta(doc, 'homelab-version')
  local ref = meta(doc, 'homelab-ref')
  local repo = meta(doc, 'homelab-repo')
  local page = meta(doc, 'md-preview-page')

  -- Only pages in a mounted folder need their links rewritten; links
  -- between ordinary docs/ pages already resolve on the site.
  if page and select(2, repo_path(page)) then
    local function fix(el)
      local new = rewrite(el.target, page, repo, ref)
      if new then el.target = new end
      return el
    end
    doc = doc:walk { Link = fix, Image = fix }
  end

  if version then doc.blocks:insert(footer(version, page, repo, ref)) end
  return doc
end
