# pH

Zero-effort HTML preprocessing/templating, with conditionals, includes, macros, and more.

- [Live demo.](https://refi64.com/pH/demo.html)
- [Source code.](https://github.com/kirbyfan64/pH)

```html
<div +#myid +.mycls></div> <!-- Easy ids and classes -->

<!-- If statements -->
<+ if="$config == dev" do>
  <p>Development build!</p>
<+ orelse do>
  <p>Production build!</p>
</+>

<!-- HTML includes (and conditional includes) -->
<+ include="myfile.html">
<+ if="$config == dev" include="dev.html">
<+ else include="prod.html">

<!-- Variables -->
<+ set var="value">

<!-- Expressions inside attributes -->
<+ set width="20px">
<div +style="width: $width"></div>

<+ for var to="a b c">
</+>

<!-- Macros -->
<+ macro="expand" slot>
  <p>Your name is: <+ value="$@name"></p>
  <+ if="$@?is-upper" do>
    <p>Is uppercase!</p>
  </+>

  <!-- Debug printing -->
  <+ print="is-upper: ($@?is-upper and true or false) myname: $@name">
  <+ slot>
</+>

<!-- Using macros -->
<+@ expand name="myname" is-upper>
  <p>Stuff here</p>
</+@>

<!-- Like 'include', but also imports macros -->
<+ require="myfile.html">
```

## What exactly is pH?

pH is an HTML preprocessor. But...why? There are already dozens of template languages
available.

Here's the key, though: *pH isn't a template language*.

Most current template languages have been built around the idea of rendering taking
place on the server. The server will use the template language to create a mostly-static
HTML page that's sent to the client device. Therefore, the template languages support
using normal programming languages within your templates.

Lately, however, there's been a major shift towards "serverless architecture", where
sites are rendered client-side, with the servers only managing basic tasks. Most web
frameworks have their own "templating language", usually some mix of HTML, JS, and
whatever else is useful for its usecases.

Despite this, often there's still some mundane tasks that can't easily be solved using
client-side code. For instance, you'll often have HTML files that look kind of like
this:

```html
<head>
  <title>My Cool Website</title>
  <!-- Some meta tags -->
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <meta name="description" content="My website">
  <meta name="keywords" content="my,cool,website">

  <script src="something.js"></script>
  <script src="analytics.js"></script>
</head>

<body>
  <div id="outer">
    <!-- Normal code goes here -->
  </div>

  <script src="other-analytics.js"></script>
  <script>
    // something you copy-pasted from a vendor's website
    (function(x,y,z){x.a=b+c.d;f=g;})(window);
  </script>
</body>
```

A lot of this will end up being duplicated throughout many of your HTML files. Even
worse, if you want to change, say, the description, you have to go through *every
single file* and change it. Need to add another wrapper element because your framework
decided it hates you? *Tough luck!*

pH is more oriented for this use case: a lightweight HTML preprocessor, designed for
de-duplicated the stuff that *can't* be moved to the client-side, while being simple
and easy to use.

## Getting started

### Installing pH

pH is written in Dart, and is available on both the Pub package repository and npm.
To install from pub, use:

```
$ pub global activate pH
```

To install from npm, use:

```
$ npm install -g pH
# or
$ yarn global add pH
```

### Using the CLI

Use the pH command:

```
$ pH -o output.html input.html  # process input.html and output to output.html
$ pH input.html                 # process input.html and output to the screen
$ pH -                          # process standard input and output to the screen
$ pH -Dvar=value -              # same as above, but assign 'value' to the variable 'var'
```

### Using the transformer

If you're using Pub, you can use the `pH_transformer` package:

```yaml
dependencies:
  # ...
  pH_transformer: any
transformers:
  - pH_transformer
  # ...
```

## Learning the pH language

### The magic `+`

Pretty much everything in pH revolves around the `+` tag. This is essentially the pH
variant of jQuery's `$` or Underscore/Lodash's `_`: a short, sweet character that
can be used to access everything said tool offers.

### Shorthand attributes

pH comes with shorthand for assigning ids and classes to elements:

```html
<!-- This is the same as <a id="my-id"> -->
<a +#my-id></a>

<!-- And this is the same as <a id="my-id" class="class-1 class-2"> -->
<a +.class-1 +.class-2></a>
```

### Assigning and using variables

Here's a basic pH file:

```html
<+ set a="foo" b="bar">
```

This uses the *set* command, which lets you assign variables. Here, the string *foo*
is being assigned to the variable *a*, and the string *bar* is being assigned to the
variable *b*.

You can later use these variables:

```html
<+ set a="foo" b="$a">
```

The `$` character is used to set apart variables.

The contents of a variable can be placed inside your HTML file via:

```html
<+ value="$a">
```

If you run pH on your file, you'll see *foo* come up in place of this tag.

When debugging your pH files, sometimes it can be useful to see what an expression's
value is. (The full expression language is explained later.) You can use the *print*
command for that:

```html
<+ print="$a">
```

This will print the contents of `$a` to the standard output while compiling your HTML
file.

Expressions can be used as attribute values, too, by prefixing the attribute with `+`:

```html
<+ set target="https://google.com/">
<a +href="$target"></a>
```

### Including files

You can include files via the *include* command:

```html
<+ include="file.html">
```

This tag will be replaced by the contents of `file.html`. (This will cause an error if
the included file doesn't exist.)

You can also pass variables to included files. Say `file.html` contains:

```html
<+ print="$variable">
```

You can include it via:

```html
<+ include="file.html" variable="123">
```

and this will print 123 to the screen.

### Conditionals

pH also supports conditionals. For instance:

```html
<+ if="$config == dev" include="dev.html">
```

You can call pH with something like `pH -Dconfig=dev` when building in development
mode. This is essentially the pH version of C's `#if`. Here, the *if* serves as a sort
of "prefix"; it comes before your command, and it will cause it to not be run if the
condition is false.

You can also use *else if* and *else*:

```html
<+ if="$config == dev" include="dev.html">
<+ else if="$config == prod" include="prod.html">
<+ else include="other.html">
```

The concept here is heavily inspired by the C/Java family of languages:

```c
if (config == "dev")
  include("dev.html");
else if (config == "prod")
  include("prod.html");
else
  include("other.html");
```

What if you want to guard actual HTML code with an *if* clause? This is where the *do*
command comes in handy:

```html
<+ if="$config == dev" do>
  <p>In development mode!</p>
</+>
<+ else if="$config == prod" do>
  <p>In production mode!</p>
</+>
<+ else do>
  <p>In <+ value="$config"> mode!</p>
</+>
```

Think of `<+ do>...</+>` as the same thing as C's `{ ... }`. The above is a lot like
this:

```c
if (config == "dev") {
  print("In development mode!");
} else if (config == "prod") {
  print("In production mode!");
} else {
  print("In " + config + " mode!");
}
```

However, all the `</+>`'s are a little ugly. For this, you can use the *orelse* command:

```html
<+ if="$config == dev" do>
  <p>In development mode!</p>
<+ orelse if="$config == prod" do>
  <p>In production mode!</p>
<+ orelse do>
  <p>In <+ value="$config"> mode!</p>
</+>
```

*orelse* is identical to else, but when inside an *if...do* statement, it allows you
to omit the closing tags (`</+>`).

### Expressions

pH comes with an easy-to-use expression language. The syntax will be explained in
further detail later, but here's the gist of things:

Everything is either a string or null. You can use a string by surrounding its contents
with quotes:

```perl
'my string'
"my string"
"my \"-quoted string supports escape sequences"
'my \'-quoted string supports escape sequences, too'
```

If your string doesn't contain any special characters, you can drop the quotes. For
instance, these are equivalent:

```perl
'mystring'
"mystring"
mystring
```

Variables are, as shown above, prefixed with a `$`:


```perl
$variable
```

When one or more strings or variables are next to each other, their values will be
concatenated. For example:

```html
<+ set variable="value">
<+ print="'$variable' is set to: $variable">
```

Here, there are several different expressions:

```perl
'$variable'
is
set
to:
$variable
```

Since they are all next to each other, pH will concatenate them all, separated by
spaces.

If you don't want the spaces, you can use the `+` operator:


```perl
'$variable=' + $variable
```

This will print `$variable=value`.

Expressions can be tested for equality:

```perl
$variable == 123
```

If `$variable` is equal to `123`, this will evaluated to the empty string. If the
condition is false, this will evaluate to a null value.

In pH, much like in Lua, the *only* falsy value is the null value!

Of course, inequality can be checked to (using `!=` instead of `==`).

You can check multiple conditions:

```perl
$a == 123 and $b == 456
$a == 123 or $b == 456
```

Again, the semantics here are taken from Lua: *and* will return the last value if both
are truthy, or null otherwise. *or* will return the first truthy value.

This can be used to imitate ternary conditionals:

```perl
$a == 123 and 'a is 123' or 'a is not 123'
```

Expressions can also be wrapped in parentheses to force precedence:

```perl
$a == 123 and ($loud and 'A IS 123' or 'a is 123') or ($loud and 'A IS NOT 123' or 'a is not 123')
```

Values can be inverted via `!`:

```perl
!($a == 123)
```

Last, if a variable is referenced via `$?` instead of `$`, it will evaluated to null
when undefined:

```html
<!-- ERROR: $variable is undefined -->
<+ print="my variable is $variable">
<!-- Ok -->
<+ print="my variable is ($?variable or undefined)">
```

### Macros

pH also supports macros. Here's the simplest form of a macro:

```html
<+ macro="my-macro">
  <+ value="my-macro was called with '$@value' = $@value">
</+>

<+@ my-macro value="123">
```

Notice two things:

- Attributes can be passed to a macro, where they are accessed using `$@` instead of
  `$`. These are called *macro variables*.
- Macros are referenced via `+@`.

Just like variables, macro variables can be tested for existence, this time via `$@?`:

```html
<+ macro="my-macro">
  <+ if="$@?loud" do>
    <p>I AM VERY LOUD!!</p>
  <+ orelse do>
    <p>I am not very loud...</p>
  </+>
</+>

<!-- I AM VERY LOUD!! -->
<+@ my-macro loud>
<!-- I am not very loud... -->
<+@ my-macro>
```

If you want to pass HTML to a macro, you can use the *slot* modifier and corresponding
command:

```html
<!-- The 'slot' makes the macro take child nodes -->
<+ macro="my-macro" slot>
  <p>The macros children are:</p>
  <+ slot>
</+>

<+@ my-macro>
  <p>First child.</p>
  <p>Second child.</p>
</+@>
```

Macros can also be imported from other files by using the *require* command, which is
identical to *include*, except that it also includes macros:

***In `macros.html`:***

```html
<+ macro="head">
  <title><+ value="$title"></title>
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <meta name="description" content="My website">
  <meta name="keywords" +content="'my,cool,website' + ($?extra-tags or '')">
</+>

<+ macro="wrapper" slot>
  <div id="outer">
    <my-wrapper-component>
      <+ slot>
    </my-wrapper-component>
  </div>
</+>
```

***In `index.html`:***

```html
<+ require="macros.html">

<head>
  <+@ head title="My title">
</head>

<body>
  <+@ wrapper>
    <p>My app goes here!</p>
  </+@>
</body>
```

## Using the API

### From Dart

Add pH to your pubspec:

```yaml
dependencies:
  pH: ^0.1.0
```

Then use it:

```dart
import 'package:pH/pH.dart';

void main() {
  // The API all stems from pH.compile.
  CompileResult result;
  result = pH.compile('text');
  result = pH.compile('text', vars: {'my-variable': '123'});
  result = pH.compile('text', url: 'my-file.html');

  // CompileResult has three attributes of interest: code, sourceMap, and errors.
  String code = result.code;
  print('pH outputted the following code: $code');

  String sourceMap = result.sourceMap;
  print('It also outputted the following source map: $sourceMap');

  List<CompileError> errors = result.errors;

  // Each CompileError contains a SourceSpan (from the source_span package) and a message:
  for (var error in errors) {
    print('Source span: ${error.at}');
    print('Error message: ${error.message}');
    // You can also view a nicely formatted message via CompileError.toString:
    print('Formatted error:');
    print(error.toString());
  }
}
```

When running on the Dart VM, file system access for includes and requires is automatic.
Otherwise, you'll need to provide a *FileProvider* to enable includes and requires:

```dart
import 'package:pH/pH.dart';

class MyFileProvider extends FileProvider {
  String read(String path) {
    // read should return the contents of the given path, or null if an error occurs
    if (path == 'my-file.html') {
      return '<div>Hello!</div>';
    } else {
      return null;
    }
  }
}

void main() {
  var result = pH.compile('text', fileProvider: new MyFileProvider());
}
```

### From JavaScript

Add the dependency:

```
$ npm install --save-dev pH
# or
$ yarn add pH
```

Usage:

```javascript
var pH = require('pH')

// The API all stems from pH.compile.
var result
result = pH.compile('text')
result = pH.compile('text', { vars: { myvariable: 123 } })
result = pH.compile('text', { url: 'my-file.html' })

// The result has three attributes of interest: code, sourceMap, and errors.
console.log(`pH outputted the following code string: ${result.code}`)

console.log(`It also outputted the following source map string: ${result.sourceMap}`)

// errors is an array of objects containing error info:
var errors = result.errors

for (var error of errors) {
  // Each error object looks like this:

  var exampleError = {
    // 'at' contains a span of text where the error occurred.
    at: {
      // The start of the error location
      start: {
        // Line #
        line: 1,
        // Column #
        column: 1,
        // Offset into the file
        offset: 2,
        // The url (same as passed above to pH.compile)
        url: 'my-file.html',
      },
      // Same format as start
      end: {
        // ...
      },
      // The text
      text: '<+ some-error-here>'
    },
    // The error message
    message: 'an error has occurred',
    // A nicely formatted message, containing carets and such to point to the location
    formattedMessage: 'line 1, column 1 of my-file.html: some error\n<+ some-error-here>\n^^^^^^'
  }
}
```

When running on the Node VM, file system access for includes and requires is automatic.
Otherwise, you'll need to provide a *fileProvider* to enable includes and requires:

```javascript
function fileProvider(path) {
  // the fileProvider should return the contents of the given path, or null if an error occurs
  if (path == 'my-file.html') {
    return '<div>Hello!</div>'
  } else {
    return null
  }
}

var result = pH.compile('text', { fileProvider })
```
