-- this is an example of a non-eswidget widget that should be ignored for
-- bundling

import Widget from require "lapis.html"

class OtherThing extends Widget
  content: =>
    div "hi"


