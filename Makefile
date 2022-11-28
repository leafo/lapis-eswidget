BIN=lapis-eswidget

.PHONY: build install compile_package

build:
	moonc lapis
	echo "#!/usr/bin/env lua" > bin/$(BIN)
	moonc bin/lapis-eswidget.moon -p >> bin/$(BIN)
	echo "-- v""im: set filetype=lua:" >> bin/$(BIN)
	chmod +x bin/$(BIN)

rebuild_spec:
	REBUILD_EXPECTED_OUTPUT=1 busted

local: build
	luarocks --lua-version=5.1 make --local lapis-eswidget-dev-1.rockspec

assetspec.tup::
	moon bin/lapis-eswidget.moon generate_spec --widget-dirs=spec/views --moonscript --format=tup --sourcemap --css-packages=main > $@

assetspec.json::
	moon bin/lapis-eswidget.moon generate_spec --widget-dirs=spec/views --moonscript --format=json --css-packages=main | jq

assetspec.make::
	moon bin/lapis-eswidget.moon generate_spec --widget-dirs=spec/views --moonscript --format=makefile --sourcemap --css-packages=main > $@

compile_main::
	moon bin/lapis-eswidget.moon compile_js --widget-dirs=spec/views --moonscript --package main
