fs = require 'fs'
{exec, spawn} = require 'child_process'

task 'build', 'Build dependencies of main.coffee', ->
  exec(
    "browserify coffee/main.coffee -v -o js/main.js"
    lastHandler)

task 'checkTest', 'Check the results of the test against baseline', ->
  exec(
    'diff test-baseline.txt test-results.txt'
    lastHandler)

task 'test', 'Build dependencies of test.coffee and execute it', ->
  exec(
    'coffee coffee/test.coffee > test-results.txt'
    nextHandler 'checkTest')

task 'watch', 'Watch prod source files and build changes', ->
  console.log 'Watching for changes...'
  watchFunc = if linux? then fs.watch else fs.watchFile
  watchFunc "coffee", (curr, prev) ->
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
