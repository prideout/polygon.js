fs = require 'fs'
{exec, spawn} = require 'child_process'

task 'build', 'Build dependencies of demo.coffee', ->
  exec(
    "coffee -c -b -o js src/polygon.coffee"
    lastHandler)
  exec(
    "browserify src/demo.coffee -v -o js/demo.js"
    lastHandler)

task 'checkTest', 'Check the results of the test against baseline', ->
  exec(
    'diff test-baseline.txt test-results.txt'
    lastHandler)

task 'watch', 'Watch prod source files and build changes', ->
  console.log 'Watching for changes...'
  watchFunc = if linux? then fs.watch else fs.watchFile
  watchFunc "src", (curr, prev) ->
    if +curr.mtime isnt +prev.mtime
      console.log "Saw change at #{curr.mtime}"
      invoke 'build'

lastHandler = (err, stdout, stderr) ->
  if stdout.length > 0 and stdout.substr(-1) is '\n'
    stdout = stdout.slice 0, -1
  console.log stdout + stderr

nextHandler = (task) ->
  (err, stdout, stderr) ->
    lastHandler err, stdout, stderr
    invoke(task) if not err
