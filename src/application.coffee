Display = require './display'
triangulate = require './earclipping'

class Application
  constructor: ->
    @pts = []
    @dragList = []
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

  getEdge: (x, y) ->
    p = new vec2(x, y)
    for pt, i in @pts
      v = @pts[i]
      w = @pts[(i+1) % @pts.length]
      d = distToSegmentSquared p, v, w
      return i if d < 25
    -1

  onDown: (x, y) ->
    mouse = new vec2(x, y)
    v = @getVertex x, y
    if v isnt -1
      dragItem = { offset: new vec2(), index: v }
      dragItem.offset.sub @pts[v], mouse
      @dragList = [dragItem]
      return
    e = @getEdge x, y
    return if e is -1
    a = { offset: new vec2(), index: e }
    b = { offset: new vec2(), index: e+1 }
    b.index = b.index % @pts.length
    a.offset.sub @pts[a.index], mouse
    b.offset.sub @pts[b.index], mouse
    @dragList = [a, b]

  onUp: (x, y) ->
    mouse = new vec2(x, y)
    if not @dragList.length
      @pts.push mouse
    else
      for item in @dragList
        @pts[item.index].add item.offset, mouse
      @dragList = []
    @display.setPoints @pts
    @display.setTriangles (triangulate @pts)

  onMove: (x, y) ->
    if not @dragList.length
      @display.highlightPoint = @getVertex x, y
      if @display.highlightPoint isnt -1
        @display.highlightEdge = -1
      else
        @display.highlightEdge = @getEdge x, y
      return
    mouse = new vec2(x, y)
    for item in @dragList
      @pts[item.index].add item.offset, mouse
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
