
import types from require "tableshape"

-- this is a unique indentifier for the state object returned by prop_type
-- checker type to instruct second layer of validation when render starts
RENDER_PROPS_KEY = setmetatable {}, __tostring: -> "::render_props::"

-- this is a special prop that extracts a field during render time into the
-- props table if it has not otherwise been specified. Note we use the lazy prop type syntax where a function is passed
render_prop = (t) ->
  (name) ->
    types.one_of {
      -- if the field is nil (not provided) then we add store this type checker
      -- into the state to be used later when render happens
      types.nil\tag (state, value) ->
        state[RENDER_PROPS_KEY] or= {}
        state[RENDER_PROPS_KEY][name] = t
      t
    }


{:render_prop, :RENDER_PROPS_KEY}
