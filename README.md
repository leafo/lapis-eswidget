# lapis-eswidget

This library provides a base Widget class that enables aggregation of static
JavaScript code and a unified system for initializing a widget with JavaScript
code.

A command-line tool is included for compiling a widget modules into an ES
Module that can be used in a build system like [esbuild](https://esbuild.github.io/).

## Example

```moonscript
-- widgets/my_widget.moon
class MyWidget extends require "lapis.eswidget"
  @asset_packages: {"main"}

  @es_module: [[
    import CoolThing from "./cool_thing"
    new CoolThing(widget_selector)
  ]]

  inner_content: =>
    div "Hi"

```

Extracting the module code on the command line:

```bash
lapis-eswidget compile_js --module widgets.my_widget
```

Extracting module code in code:

```moonscript
MyWidget = require("widgets.my_widget")

print MyWidget\compile_es_module!
```

Building an entire package the module code on the command line:

> Note: You generally want to use `generate_spec` to create instructions to
> build a package incrementally. --package mode may be slow since it will scan
> and evaluate the entire widget filesystem tree

```bash
lapis-eswidget compile_js --package main
```

## `lapis-eswidget` command line tool

The `lapis-eswidget` command can be used to work with widget modules,
extracting code or generating instructions to create the final bundles.

    Usage: lapis-eswidget [-h] [--moonscript] <command> ...

    Widget asset compilation and build generation

    Options:
       -h, --help            Show this help message and exit.
       --moonscript          Enable MoonScript module loading

    Commands:
       compile_js            Compile a single module or entire package to JavaScript
       generate_spec         Scan widgets and generate specification for compiling bundles
       debug                 Show any extractable information about a widget module

The following commands are included

### `compile_js`

```
lapis-eswidget compile_js --help

Usage: lapis-eswidget compile_js [-h] [--module <module>]
       [--file <file>] [--package <package>]
       [--widget-dirs <widget_dirs>]

Compile a single module or entire package to JavaScript

Options:
   -h, --help            Show this help message and exit.
   --module <module>
   --file <file>
   --package <package>
   --widget-dirs <widget_dirs>
                         Paths where widgets are located. Only used for compiling by --package (default: views,widgets)

```

Compile a single module or entire package to JavaScript. One of the following
sources must be specified:

* `--file` - Load by the filename of a Lua module that contains an ESWidget (eg. `views/profile.lua`)
* `--module` - Load by Lua module name (eg. `views.profile`)
* `--package` - Will scan filesystem (see `--widget-dirs`) and concatenate the output of all Lua modules that extend ESWidget and specify the package in `@asset_packages`

If you want to enable loading MoonScript modules then you must pass `--moonscript`

### `generate_spec`

```
lapis-eswidget generate_spec --help

Usage: lapis-eswidget generate_spec [-h] [--widget-dirs <widget_dirs>]
       [--format {json,tup,makefile}] [--minify {both,only,none}]
       [--sourcemap] [--css-packages <css_packages>]
       [--source-dir <source_dir>] [--output-dir <output_dir>]
       [--esbuild-bin <esbuild_bin>]
       [--tup-compile-dep-group <tup_compile_dep_group>]
       [--tup-bundle-dep-group <tup_bundle_dep_group>]

Scan widgets and generate specification for compiling bundles

Options:
   -h, --help            Show this help message and exit.
   --widget-dirs <widget_dirs>
                         Paths where widgets are located (default: views,widgets)
   --format {json,tup,makefile}
                         Output fromat for generated asset spec file (default: json)
   --minify {both,only,none}
                         Set how minified bundles should be generated (default: both)
   --sourcemap           Enable sourcemap for bundled outputs
   --css-packages <css_packages>
                         Instruct build that css files will be generated for listed packages
   --source-dir <source_dir>
                         The working directory for source files (NODE_PATH will be set to this during bundle) (default: static/js)
   --output-dir <output_dir>
                         Destination of final compiled asset packages (default: static)
   --esbuild-bin <esbuild_bin>
                         Set the path to the esbuild binary. When empty, will use the ESBUILD tup environment variable
   --tup-compile-dep-group <tup_compile_dep_group>
                         Dependency group used during the widget -> js compile phase (eg. $(TOP)/<moon>)
   --tup-bundle-dep-group <tup_bundle_dep_group>
                         Dependency group used during esbuild bundling phase (eg. $(TOP)/<coffee>)

```

Scan directories for widgets that extend from `ESWidget` and generate a
specification for compiling bundles. This intermediate file is called an *Asset Spec*.

Supports the following output formats: `json`, `tup`, `makefile`

### `debug`

```
lapis-eswidget debug --help
```

Display information about a single widget

## `ESWidget` base class

Any widgets you wish to be supported by this library must extend from
`ESWidget`.

```moonscript
ESWidget = require "lapis.eswidget"
```


### Inerface

Class

* `@asset_packages` (array table, default: `{}`) - The packages that this widget's assets will be placed into
* `@widget_name` (function) - Returns a name for the widget used for class names and file names (eg. MyWidget -> my_widget)
* `@widget_class_name` (function) - Returns the CSS class name of this widget as a string
* `@widget_class_list` (function) - Return variable number of arguments for the list of CSS classes this widget will have when rendered, calculated from the inheritance chain
* `@compile_es_module` (function) - Compile the static `es_module` initialization code for the widget

Class properties

* `@es_module` (string, default: `nil`) - The initialization JavaScript for the widget
* `@prop_types` (table, default: `nil`) - Enables property validation for the widget, with a table mapping names to a tableshape type

Instance

* `widget_id` (function) - Returns a string with a unique ID for the widget, of the format `{widget_name}_{random_number}`
* `widget_selector` (function) - Returns a snippet of JavaScript that can be used to uniquely identify the element on the page
* `widget_enclosing_element` (string, default: `"div"`)
* `widget_enclosing_attributes` (function)
* `js_init(params)` (function) - Returns JavaScript code that will be embedded with `raw` to initialize the widget on the page
* `content` (function)
* `inner_content` (function, default: empty function) - The render function of the widget called inside of the enclosing element

### Static vs Instance code

There are two kinds of data associated with each widget during it's render
lifecycle:

**Static** code and data is unchanging and can be compiled and used during the
ahead-of-time building of packages. This includes things like the ES Module
initialization function (`@@es_module`), CSS classnames.

**Instance** code and data is only available during the rendering of a widget
during a request. This could include things like the dynamically created widget
ID to uniquely referencing its element on a page, parameters to JavaScript
initialization.

### HTML Encapsulation

The `ESWidget` class provides a default `content` method that will
automatically generate a class and ID for an HTML element to allow it to be
uniquely identified by JavaScript initialization, and generally identified by CSS
selectors.

To user encapsulation, the `inner_content` method must be implemented instead
of the `content` method on the widget sub-class, otherwise the enclosing
element logic will be overwritten.

The generated class names will utilize the entire class hierarchy:

```moonscript
class One extends require "lapis.eswidget"
class Two extends One
class Three extends Two


One\widget_class_list! -->  "one_widget"
Two\widget_class_list! --> "two_widget", "one_widget"
Three\widget_class_list! -->  "three_widget", "two_widget", "one_widget"
```

### Parameter Validation

The base ESWidget class has a mechanism to validate inputs passed into the
Widget. The `prop_types` field takes a table of names and *tableshape* types
to be used to validate the values of the inputs.


```moonscript
class MyThing extends require "lapis.eswidget"
  @prop_types: {
    name: types.string -- this is a required input
    banned: types.boolean\is_optional!
  }

  inner_content: =>
    h2 @props.name
    if @props.banned
      p "You are banned"
    else
      p "You are not banned"

widget1 = MyThing name: "Cool", banned: true

widget2 = MyThing name: 2323 --> this will fail with an error
```

Providing `@prop_types` will change the default behavior of the constructor. As
a reminder, the default `Widget` constructor copies every field from the
argument object onto the widget instance. When `@prop_types` is used, the
inputs will be validated and collected into an object called `props` that will
be stored on the widget instance.  Eg. you would access name with `@props.name`
instead of `@name` in the example above.

By default `prop_types` will only validate the object passed into the
constructor.  A widget can actually receive a second source of inputs though.
In Lapis, when a widget renders, an internal helper chain is set that includes
a reference to the *Request* object. This is how you can access things like
`@url_for`, and it is also how you access fields that are set during the
request action handler.

In order to validate render-time inputs, you must flag the prop type with the
`render_prop` function. This will allow the prop_type to validate from the
render helper chain if the value was not provided directly to the constructor.
The result will be copied into the `props` field regardless.


```moonscript
import types from require "tableshape"
import render_prop from require "lapis.eswidget.prop_types"

class UserProfile extends require "lapis.eswidget"
  @prop_types: {
    language: types.string -- this is a required input
    user: render_prop types.table
  }


-- the `user` field provided in the constructor will take precedence. No
-- additional validation is done at render time
profile1 = UserProfile language: "en", user: {id: 10}

-- the `user` field here will be validated when the widget is rendered, so this
-- will not throw an error
profile2 = UserProfile language: "en"
```

### Asset Packages

The `asset_packages` class field is an array of package names that a widget's
assets should be aggregated into when bundling. No asset package names are set
by default, if you wish to aggregate assets then you will need to provide at
least one asset package.

The end result of bundling will result in a file (or files) containing output
from widgets that target that package, eg. `main` → `main.js`, `main.css`

Multiple asset packages can be used for splitting code at a high level to
reduce total bundle sizes.

The first asset package in the list of asset packages is used to calculate the
canonical path for Associated Files (see below).

### Associated Files

**TODO**: This is not exposed currently

An associated file is a file related to the widget that is manually written (as
opposed to generated by the build system). These files have code
implementations of logic that is too big to be placed directly into the Widget
class declaration.

The naming convention is: 

`/static/{asset_type}/{asset_package}/{widget_path}.{ext}`

* Where `asset_type` is like `css`, `js`, `scss`, `coffee` etc.
* Where `asset_package` is the first package specified by the widget, like `main`, `admin`, etc. (Packages are user-defined and can be anything)
* Where `widget_path` the conversion of the widget's module name to a path, like `widgets.hello.world` -> `hello/world` (Note the module prefix is not included)
* And `ext` is the appropriate extension for the file

