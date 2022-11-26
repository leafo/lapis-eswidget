package = "lapis-eswidget"
version = "dev-1"
source = {
  url = "git+ssh://git@github.com/leafo/lapis-eswidget.git"
}
description = {
  summary = "A widget base class designed for generating ES modules for bundling JavaScript & more",
  license = "MIT",
  maintainer = "Leaf Corcoran <leafot@gmail.com>",
  homepage = "https://github.com/leafo/lapis-eswidget",
}

dependencies = {
  "lua >= 5.1",
  "lapis",
  "argparse",
  "tableshape",
}

build = {
  type = "builtin",
  modules = {
    ["lapis.cmd.actions.eswidget"] = "lapis/cmd/actions/eswidget.lua",
    ["lapis.eswidget.cmd"] = "lapis/eswidget/cmd.lua",
    ["lapis.eswidget"] = "lapis/eswidget.lua",
    ["lapis.eswidget.render_flow"] = "lapis/eswidget/render_flow.lua",
  },
  install = {
    bin = { "bin/lapis-eswidget" }
  }
}
