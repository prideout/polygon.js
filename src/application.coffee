Display = require './display'

Mode =
  HOLE: 0
  CONTOUR: 1
  VISUALIZE: 2

TopInstructions1 =  """
<p>
  To form a hole, click around inside the outer
  contour in <b>clockwise</b> order.
</p>"""

TopInstructions2 =  """
<p>
  Click the WebGL canvas at various points in <b>counter-clockwise</b> order to create a simple polygon.
  It can be concave if you want!
</p>"""

TopInstructions3 =  """
<p>
  The ear clipping algorithm can tessellate concave polygons with holes.
  To draw your own polygon, click <span class="doneButton">here</span>
  or press enter.
</p>"""

BottomInstructions =  """
<p>
  Press the <b>d</b> key to delete the most recently added point.  You can also use the mouse to drag
  existing vertices and edges.  Hold the shift key to drag the entire polyline.
</p>
<p>
  When you're done, click <span class="doneButton">here</span> or press enter.
</p>"""

startFigure = true
simpleStartFigure = false

class Application
  constructor: ->
    @shiftKey = false
    if startFigure
      if simpleStartFigure
        c = [{"x":500,"y":300},{"x":453.2088886237956,"y":171.44247806269215},{"x":334.7296355333861,"y":103.0384493975584},{"x":200.00000000000006,"y":126.79491924311225},{"x":112.06147584281834,"y":231.59597133486622},{"x":112.06147584281831,"y":368.40402866513375},{"x":199.99999999999991,"y":473.2050807568877},{"x":334.729635533386,"y":496.96155060244166}]
        h = [{"x":328,"y":340},{"x":312,"y":326},{"x":318,"y":301},{"x":349,"y":297}]
      else
        c =  [{"x":440,"y":502},{"x":414,"y":438},{"x":404,"y":355},{"x":394,"y":298},{"x":442,"y":278},{"x":470,"y":265},{"x":480,"y":252},{"x":489,"y":232},{"x":508,"y":198},{"x":467,"y":173},{"x":437,"y":236},{"x":395,"y":251},{"x":361,"y":257},{"x":324,"y":212},{"x":317,"y":170},{"x":327,"y":150},{"x":349,"y":125},{"x":367,"y":82},{"x":353,"y":56},{"x":308,"y":22},{"x":244,"y":40},{"x":233,"y":75},{"x":258,"y":146},{"x":278,"y":159},{"x":299,"y":216},{"x":282,"y":277},{"x":228,"y":246},{"x":168,"y":180},{"x":159,"y":167},{"x":117,"y":207},{"x":194,"y":249},{"x":223,"y":277},{"x":263,"y":304},{"x":277,"y":385},{"x":259,"y":406},{"x":225,"y":429},{"x":217,"y":435},{"x":159,"y":496},{"x":293,"y":520},{"x":284,"y":451},{"x":315,"y":406},{"x":323,"y":381},{"x":351,"y":391},{"x":354,"y":421},{"x":370,"y":458},{"x":344,"y":487},{"x":335,"y":535}]
        h =  [{"x":348,"y":303},{"x":340.46979603717466,"y":318.6366296493606},{"x":323.5495813208737,"y":322.49855824363647},{"x":309.98062264195164,"y":311.6776747823512},{"x":309.98062264195164,"y":294.3223252176488},{"x":323.5495813208737,"y":283.50144175636353},{"x":340.46979603717466,"y":287.3633703506394}]
      @contourPts = (new vec2(o.x, o.y) for o in c)
      @holePts = (new vec2(o.x, o.y) for o in h)
    else
      @contourPts = []
      @holePts = []
    @mode = Mode.HOLE
    @dragList = []
    if @initDisplay()
      @nextMode()
      @assignEventHandlers()
      @requestAnimationFrame()
    if startFigure
      @updateDisplay()

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
    triangles = POLYGON.tessellate @contourPts, holes
    @display.setTriangles triangles

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
    return -1 if not @pts
    p = new vec2(x, y)
    for pt, i in @pts
      d = pt.distanceToSquared p
      return i if d < 25
    -1

  getEdge: (x, y) ->
    return -1 if not @pts
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
    return if not @pts
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
    return if not @pts
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
        @display.freezeContour = true
        @display.visualize = false
        $('#top-instructions').html TopInstructions1
        $('#bottom-instructions').html BottomInstructions
    else if @mode is Mode.HOLE
        @mode = Mode.VISUALIZE
        @pts = null
        @display.visualize = true
        @display.setHighlightEdge -1
        @display.highlightPoint = -1
        $('#top-instructions').html TopInstructions3
        $('#bottom-instructions').html ''
    else if @mode is Mode.VISUALIZE
        if startFigure
          @contourPts = []
          @holePts = []
          startFigure = false
        @mode = Mode.CONTOUR
        @pts = @contourPts
        @display.freezeContour = false
        @display.visualize = false
        $('#top-instructions').html TopInstructions2
        $('#bottom-instructions').html BottomInstructions
    @updateDisplay()

  circlify: ->
    @pts.push new vec2(0, 0)
    dtheta = 2 * Math.PI / @pts.length
    theta = 0
    flip = if @mode is Mode.CONTOUR then -1 else +1
    radius = if @mode is Mode.CONTOUR then 200 else 20
    for pt in @pts
      pt.x = 300 + radius * Math.cos theta
      pt.y = 300 + flip * radius * Math.sin theta
      theta = theta + dtheta
    @updateDisplay()

  setShiftKey: ->
    if @shiftKey
      @display.highlightPoint = -2
      @display.setHighlightEdge -1
    else if @display.highlightPoint is -2
      @display.highlightPoint = -1

  dumpPoints: ->
    console.info "contourPts = ", JSON.stringify @contourPts
    console.info "holePts = ", JSON.stringify @holePts

  assignEventHandlers: ->

    # Honoring e.shiftKey seems to be unreliable on some platforms.
    # http://cross-browser.com/x/examples/shift_mode.php
    $(document).bind 'keydown', (e) =>
      if e.keyCode is 16
        @shiftKey = true
        @setShiftKey @shiftKey
    $(document).bind 'keyup', (e) =>
      if e.keyCode is 16
        @shiftKey = false
        @setShiftKey @shiftKey

    $(document).on 'click', '.doneButton', => @nextMode()
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
      @dumpPoints() if s is 'P'
      @nextMode() if e.keyCode is 13

module.exports = Application
