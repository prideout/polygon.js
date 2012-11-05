gl = null

class Display
  constructor: (context, @width, @height) ->
    gl = context
    @ready = false
    gl.clearColor(0.9,0.9,0.9,1.0)
  render: ->
    gl.clear(gl.COLOR_BUFFER_BIT)
  setPoints: (pts) ->
    console.info 'points:', pts

module.exports = Display
