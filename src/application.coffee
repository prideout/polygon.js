Display = require './display'
tessellate = (require './earclipping').tessellate

Mode =
  HOLE: 0
  CONTOUR: 1

Instructions1 =  """
<p>
  To form a hole, click around inside the outer
  contour in <b>clockwise</b> order.
</p>"""

Instructions2 =  """
<p>
  Click the WebGL canvas at various points in <b>counter-clockwise</b> order to create a simple polygon.
  It can be concave if you want!
</p>"""

class Application
  constructor: ->
    @shiftKey = false
    @contourPts = []
    @holePts = []
    @mode = Mode.HOLE
    @nextMode()
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

  updateDisplay: ->
    @display.setPoints @contourPts, @holePts
    holes = [@holePts]
    [triangles, slice] = tessellate @contourPts, holes
    @display.setTriangles triangles
    @display.setSliceEdge slice

  updateHighlight: (x, y) ->
    if @shiftKey
      @display.highlightPoint = -2
      @display.setHighlightEdge -1
      return
    p = @getVertex x, y
    e = if p is -1 then (@getEdge x, y) else -1
    if @mode is Mode.HOLE
      if p isnt -1
        p = p + @contourPts.length
      if e isnt -1
        e = e + @contourPts.length
    @display.highlightPoint = p
    @display.setHighlightEdge e

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
    if @shiftKey
      @dragList = []
      for e in [0...@pts.length]
        item = { offset: new vec2(), index: e }
        item.offset.sub @pts[item.index], mouse
        @dragList.push item
      $('canvas').css {cursor : 'none'}
      return
    v = @getVertex x, y
    if v isnt -1
      dragItem = { offset: new vec2(), index: v }
      dragItem.offset.sub @pts[v], mouse
      @dragList = [dragItem]
      $('canvas').css {cursor : 'none'}
      return
    e = @getEdge x, y
    return if e is -1
    a = { offset: new vec2(), index: e }
    b = { offset: new vec2(), index: e+1 }
    b.index = b.index % @pts.length
    a.offset.sub @pts[a.index], mouse
    b.offset.sub @pts[b.index], mouse
    @dragList = [a, b]
    $('canvas').css {cursor: 'none'}

  onUp: (x, y) ->
    mouse = new vec2(x, y)
    if not @dragList.length
      @pts.push mouse
    else
      $('canvas').css {cursor: 'default'}
      for item in @dragList
        @pts[item.index].add item.offset, mouse
      @dragList = []
    @updateDisplay()

  onMove: (x, y) ->
    if not @dragList.length
      @updateHighlight x, y
      return
    mouse = new vec2(x, y)
    for item in @dragList
      @pts[item.index].add item.offset, mouse
    @updateDisplay()

  removePoint: ->
    return if @pts.length < 1
    @pts.pop()
    @updateDisplay()

  nextMode: ->
    if @mode is Mode.CONTOUR
        @mode = Mode.HOLE
        @pts = @holePts
        @display?.freezeContour = true
        $('#instructions').html Instructions1
    else
        @mode = Mode.CONTOUR
        @pts = @contourPts
        @display?.freezeContour = false
        $('#instructions').html Instructions2

  circlify: ->
    @pts.push new vec2(0, 0)
    dtheta = 2 * Math.PI / @pts.length
    theta = 0
    for pt in @pts
      pt.x = 300 + 200 * Math.cos theta
      pt.y = 300 - 200 * Math.sin theta
      theta = theta + dtheta
    @updateDisplay()

  setShiftKey: (isDown) ->
    @shiftKey = isDown
    if @shiftKey
      @display.highlightPoint = -2
      @display.setHighlightEdge -1
    else if @display.highlightPoint is -2
      @display.highlightPoint = -1

  assignEventHandlers: ->
    $(document).bind 'keyup keydown', (e) => @setShiftKey e.shiftKey
    $('#doneButton').click (e) => @nextMode()
    c = $('canvas')
    c.mousemove (e) => @onMove e.offsetX, e.offsetY
    c.mousedown (e) =>
      @onDown e.offsetX, e.offsetY
      e.originalEvent.preventDefault()
    c.mouseup (e) => @onUp e.offsetX, e.offsetY
    $(document).keyup (e) =>
      s = String.fromCharCode(e.keyCode)
      @removePoint() if s is 'D'
      @circlify() if s is 'C'
      @nextMode() if e.keyCode is 13

module.exports = Application
