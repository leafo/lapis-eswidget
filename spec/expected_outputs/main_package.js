// spec/views/login.moon (main)
import "./login.css"
import {Thing} from "lib/test"
window.init_Login = function(widget_selector, widget_params) {
    console.log("Login!", widget_selector, widget_params)
    Thing()
}

// spec/views/user_profile.moon (main)
window.init_UserProfile = function(widget_selector, widget_params) {
    console.log("User profile!", widget_selector, widget_params)
}

// spec/views/user/settings.moon (main, settings)
window.init_UserSettings = function(widget_selector, widget_params) {
    console.log("User settings!", widget_selector, widget_params)
}

