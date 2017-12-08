# pH

Zero-effort HTML preprocessing/templating, with conditionals, includes, macros, and more.

## Learning More

Check out [the docs](https://refi64.com/pH).

## Example

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
