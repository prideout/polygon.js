Display = require './display'
triangulate = require './earclipping'

class Application

  constructor: ->
    @pts = []
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

  injectPoints: ->
    @display.setPoints @pts
    indices = triangulate @pts
    @display.setTriangles indices

  onClick: (x, y) ->
    @pts.push new vec2(x, y)
    @injectPoints() if @display?

  onMove: (x, y) ->
    p = new vec2(x, y)
    @display.highlightPoint = -1
    for pt, i in @pts
      d = pt.distanceToSquared p
      if d < 25
        @display.highlightPoint = i

  removePoint: ->
    return if @pts.length < 1
    @pts.pop()
    @injectPoints()

  assignEventHandlers: ->
    $(window).resize => @onResize()

    $(document).keydown (e) =>
      @removePoint() if e.keyCode is 68
      @nextMode() if e.keyCode is 13

    $('canvas').click (e) =>
      @onClick e.offsetX, e.offsetY

    $('canvas').mousemove (e) =>
      @onMove e.offsetX, e.offsetY

module.exports = Application
