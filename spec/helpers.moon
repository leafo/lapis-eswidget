-- note: we can't do stub(_G, "pairs") because of a limitation of busted
sorted_pairs = (sort=table.sort) ->
  import before_each, after_each from require "busted"
  local _pairs
  before_each ->
    -- clear out any loded lapis modules to ensure clean slate
    for mod_name in pairs package.loaded
      if mod_name == "lapis" or mod_name\match "^lapis%."
        package.loaded[mod_name] = nil

    _pairs = _G.pairs
    _G.pairs = (object, ...) ->
      keys = [k for k in _pairs object]
      sort keys, (a,b) ->
        if type(a) == type(b)
          tostring(a) < tostring(b)
        else
          type(a) < type(b)

      idx = 0

      ->
        idx += 1
        key = keys[idx]
        if key != nil
          key, object[key]

  after_each ->
    _G.pairs = _pairs

{:sorted_pairs}
