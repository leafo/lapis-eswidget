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
lapis-eswidget compile_js widgets.my_widget
```

Extracting module code in code:

```moonscript
MyWidget = require("widgets.my_widget")

print MyWidget\compile_es_module!
```

## Static vs Instance code

There are two kinds of data assoaciated with each widget during it's render
lifecycle:

**Static** code and data is unchanging and can be compiled and used during the
ahead-of-time building of packages. This includes things like the ES Module
initializatioon function (`@@es_module`), CSS classnames.

**Instance** code and data is only available during the rendering of a widget
during a request. This could include things like the dynamically created
widget ID to uniquely referencing its element on a page.

## HTML Encapsulation

The `ESWidget` class provides a default `content` method that will
automatically generate a class and ID for an HTML element to allow it to be
uniquely identified by JavaScript initializion, and generally identified by CSS
selectors.

To user encapsulation, the `inner_content` method must be implemented instead
of the `content` method on the widget sub-class, otherwise the enclosing
element logic will be overwritten.

The generated class names will utilize the entire class hierachy:

```
class One extends require "lapis.eswidget"
class Two extends One
class Three extends Two


One\class_list! --> 
Two\class_list! --> 
Three\class_list! --> 
```

## Parameter Validation

TODO: `render_types` and `prop_types`

## Asset Packages

The `asset_packages` class field is an array of package names that a widget's
assets should be aggregated into when bundling. No asset package names are set
by default, if you wish to aggregate assets then you will need to provide at
least one asset package.

The end result of bundling will result in a file (or files) containing output
from widgets that target that package, eg `main` → `main.js`, `main.css`

Multiple asset packages can be used for splitting code at a high level to
reduce total bundle sizes.

The first asset package in the list of asset packages is used to calculate the
canonical path for Associated Files (see below).

## Building Asset Spec

The `lapis-eswidget` command can be used to scan widget directories and output
a build file that can be used by a build system to generate the final asset
packages. This intermediate file is called the *Asset Spec*.

## Associated Files

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

