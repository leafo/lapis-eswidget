
import argparser from require("lapis.cmd.actions.eswidget")

parser = assert argparser!, "Failed to get parser"
args = parser\parse [v for _, v in ipairs _G.arg]

import run from require("lapis.eswidget.cmd")

run args

