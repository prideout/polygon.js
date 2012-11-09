Display = require './display'
triangulate = require './earclipping'

class Application
  constructor: ->
    @pts = []
    @dragVertex = -1
    if @initDisplay()
      @assignEventHandlers()
      @requestAnimationFrame()

  initDisplay: ->
    try
      c = $('canvas').get 0
      gl = c.getContext 'experimental-webgl', antialias: true
      throw new Error() if not gl
    catch error
      msg = 'Alas, your browser does not support WebGL.'
      $('canvas').replaceWith "<p class='error'>#{msg}</p>"
    return false if not gl
    width = parseInt $('canvas').css('width')
    height = parseInt $('canvas').css('height')
    @display = new Display(gl, width, height)

  requestAnimationFrame: ->
    onTick = => @tick()
    window.requestAnimationFrame onTick, @canvas

  tick: ->
    @requestAnimationFrame()
    @display.render()

  onResize: ->
    #tbd

  getVertex: (x, y) ->
    p = new vec2(x, y)
    for pt, i in @pts
      d = pt.distanceToSquared p
      return i if d < 25
    -1

  onDown: (x, y) ->
    v = @getVertex x, y
    if v > -1
      @dragVertex = v

  onUp: (x, y) ->
    if @dragVertex is -1
      @pts.push new vec2(x, y)
    else
      @pts[@dragVertex] = new vec2(x, y)
      @dragVertex = -1
    @display.setPoints @pts
    @display.setTriangles (triangulate @pts)

  onMove: (x, y) ->
    @display.highlightPoint = @getVertex x, y
    return if @dragVertex is -1
    @pts[@dragVertex] = new vec2(x, y)
    @display.setPoints @pts
    @display.setTriangles (triangulate @pts)

  removePoint: ->
    return if @pts.length < 1
    @pts.pop()
    @display.setPoints @pts
    @display.setTriangles (triangulate @pts)

  assignEventHandlers: ->
    $(window).resize => @onResize()
    c = $('canvas')
    c.mousemove (e) => @onMove e.offsetX, e.offsetY
    c.mousedown (e) => @onDown e.offsetX, e.offsetY
    c.mouseup (e) => @onUp e.offsetX, e.offsetY
    $(document).keydown (e) =>
      @removePoint() if e.keyCode is 68
      @nextMode() if e.keyCode is 13

module.exports = Application
