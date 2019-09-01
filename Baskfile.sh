task_default() {
  bask_log_error 'There is no default task!'
  return 1
}

js() {
  preamble=`awk -F:// '/^node_preamble/ { print $2; }' protic/.packages`
  [ -f "$preamble/preamble.js" ] || \
    bask_log_error 'Cannot find node_preamble preamble.js'

  if [ "$1" == "release" ]; then
    preamble_js="$preamble/preamble.min.js"
    dart2js_flags=-m
  else
    preamble_js="$preamble/preamble.js"
    dart2js_flags=
  fi

  mkdir -p protic-js/build
  bask_run dart2js --omit-implicit-checks $dart2js_flags -o protic-js/build/protic.js \
            protic/lib/src/js/entrypoint.dart
  mv protic-js/build/protic.js protic-js/build/protic.0.js
  cat \
    <(echo 'if (typeof self === "undefined") {') \
    "$preamble_js" \
    <(echo '}') \
    protic-js/build/protic.0.js > protic-js/build/protic.js
  rm protic-js/build/protic.0.js
}

task_js() {
  js
}

task_js_release() {
  js release
}

task_site() {
  [ -d "site" ] || git clone https://github.com/kirbyfan64/protic.git site -b gh-pages
  cp -r docs/index.html docs/README.md protic-js/demo.html protic-js/build site
}
