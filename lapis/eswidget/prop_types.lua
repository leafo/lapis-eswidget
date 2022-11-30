local types
types = require("tableshape").types
local RENDER_PROPS_KEY = setmetatable({ }, {
  __tostring = function()
    return "::render_props::"
  end
})
local render_prop
render_prop = function(t)
  return function(name)
    return types.one_of({
      types["nil"]:tag(function(state, value)
        local _update_0 = RENDER_PROPS_KEY
        state[_update_0] = state[_update_0] or { }
        state[RENDER_PROPS_KEY][name] = t
      end),
      t
    })
  end
end
return {
  render_prop = render_prop,
  RENDER_PROPS_KEY = RENDER_PROPS_KEY
}
