task_default() {
  bask_log_error 'There is no default task!'
  return 1
}

js() {
  preamble=`awk -F:// '/^node_preamble/ { print $2; }' .packages`
  [ -f "$preamble/preamble.js" ] || \
    bask_log_error 'Cannot find node_preamble preamble.js'

  if [ "$1" == "release" ]; then
    preamble_js="$preamble/preamble.min.js"
    dart2js_flags=-m
  else
    preamble_js="$preamble/preamble.js"
    dart2js_flags=
  fi

  mkdir -p pH-js/build
  bask_run dart2js --trust-type-annotations $dart2js_flags -o pH-js/build/pH.js \
            pH/lib/src/js/entrypoint.dart
  mv pH-js/build/pH.js pH-js/build/pH.0.js
  cat \
    <(echo 'if (typeof self === "undefined") {') \
    "$preamble_js" \
    <(echo '}') \
    pH-js/build/pH.0.js > pH-js/build/pH.js
  rm pH-js/build/pH.0.js
}

task_js() {
  js
}

task_js_release() {
  js release
}

task_site() {
  [ -d "site" ] || git clone https://github.com/kirbyfan64/pH.git -b gh-pages
  cp -r docs/index.html docs/README.md pH-js/demo.html pH-js/build site
}
