
class Login extends require "lapis.eswidget"
  @asset_packages: {"main"}

  @es_module: [[
    import "./login.css"
    import {Thing} from "lib/test"

    console.log("Login!", widget_selector, widget_params)
    Thing()
  ]]
