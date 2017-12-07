# ph

Zero-effort, compile-time HTML conditionals, includes, macros, and more.

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

<!-- Macros -->
<+ set var="value">

<+ macro="expand">
  <p>Your name is: <+ value="$@myname"></p>
  <+ if="$@is-upper">
    <p>Is uppercase!</p>
  </+>

  <!-- Debug printing -->
  <+ print="is-upper: $@is-upper myname: $@myname">
  <+ slot>
</+>

<!-- Using macros -->
<+@ expand name="myname" is-upper>
  <p>Stuff here</p>
</+@>

<!-- Like 'include', but also imports macros -->
<+ require="myfile.html">
```
