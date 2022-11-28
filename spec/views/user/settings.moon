
class Login extends require "lapis.eswidget"
  @asset_packages: {"main", "settings"}

  @es_module: [[
    console.log("User settings!", widget_selector, widget_params)
  ]]
