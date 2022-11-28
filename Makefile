BIN=lapis-eswidget

.PHONY: build install compile_package

build:
	moonc lapis
	echo "#!/usr/bin/env lua" > bin/$(BIN)
	moonc bin/lapis-eswidget.moon -p >> bin/$(BIN)
	echo "-- v""im: set filetype=lua:" >> bin/$(BIN)
	chmod +x bin/$(BIN)

local: build
	luarocks --lua-version=5.1 make --local lapis-eswidget-dev-1.rockspec

assetspec.tup::
	moon bin/lapis-eswidget.moon generate_spec --widget-dirs=spec/views --moonscript --format=tup > $@

assetspec.json::
	moon bin/lapis-eswidget.moon generate_spec --widget-dirs=spec/views --moonscript --format=json | jq

assetspec.make::
	moon bin/lapis-eswidget.moon generate_spec --widget-dirs=spec/views --moonscript --format=makefile > $@

compile_main::
	moon bin/lapis-eswidget.moon compile_js --widget-dirs=spec/views --moonscript --package main
