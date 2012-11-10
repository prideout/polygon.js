gl = null

semantics =
  POSITION : 0
  VERTEXID : 0
  NORMAL   : 1
  TEXCOORD : 2

shaders = {}

shaders.dot =
  vs: ['dotvs']
  fs: ['dotfs']
  attribs:
    Position: semantics.POSITION

shaders.contour =
  vs: ['contourvs']
  fs: ['contourfs']
  attribs:
    Position: semantics.POSITION

class Display
  constructor: (context, @width, @height) ->
    gl = context
    @programs = compilePrograms shaders
    @pointSprite = loadTexture 'textures/PointSprite.png'
    @coordsArray = []
    @coordsBuffer = gl.createBuffer()
    @indexArray = []
    @indexBuffer = gl.createBuffer()
    @lineBuffer = gl.createBuffer()
    @highlightPoint = -1
    @highlightEdge = -1
    gl.clearColor 0.9, 0.9, 0.9, 1.0
    gl.lineWidth 2
    gl.enable gl.BLEND
    gl.blendFunc gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA

  render: ->
    gl.clear gl.COLOR_BUFFER_BIT
    return if @coordsArray.length is 0

    mv = new mat4()
    proj = new mat4()
    proj.makeOrthographic(0, 600, 0, 600, 0, 1)

    gl.bindBuffer gl.ARRAY_BUFFER, @coordsBuffer
    gl.enableVertexAttribArray semantics.POSITION
    gl.vertexAttribPointer semantics.POSITION, 2, gl.FLOAT, false, stride = 8, 0

    program = @programs.contour
    gl.useProgram program
    gl.uniformMatrix4fv program.modelview, false, mv.elements
    gl.uniformMatrix4fv program.projection, false, proj.elements

    if @indexArray.length > 0
      program = @programs.contour
      gl.useProgram program
      gl.uniform4f program.color, 0.25, 0.25, 0, 0.5
      gl.bindBuffer gl.ELEMENT_ARRAY_BUFFER, @indexBuffer
      gl.drawElements gl.TRIANGLES, 3 * @indexArray.length, gl.UNSIGNED_SHORT, 0

    if @coordsArray.length > 1
      program = @programs.contour
      gl.useProgram program

      # Draw the outer contour
      gl.uniform4f program.color, 0, 0.4, 0.8, 1
      gl.drawArrays gl.LINE_LOOP, 0, @numContourPoints

      # Draw the hole outline (if it exists)
      pointCount = @coordsArray.length - @numContourPoints
      if pointCount
        gl.uniform4f program.color, 0.8, 0.4, 0, 1
        gl.drawArrays gl.LINE_LOOP, @numContourPoints, pointCount

      if @highlightEdge > -1
        gl.lineWidth 4
        gl.uniform4f program.color, 0, 0, 0, 1
        gl.bindBuffer gl.ELEMENT_ARRAY_BUFFER, @lineBuffer
        gl.drawElements gl.LINES, 2, gl.UNSIGNED_SHORT, 0
        gl.lineWidth 2

    program = @programs.dot
    gl.useProgram program
    gl.uniformMatrix4fv program.modelview, false, mv.elements
    gl.uniformMatrix4fv program.projection, false, proj.elements
    gl.uniform1f program.pointSize, 8
    gl.bindTexture gl.TEXTURE_2D, @pointSprite

    if not @freezeContour
      pointOffset = 0
      pointCount = @numContourPoints
    else
      pointOffset = @numContourPoints
      pointCount = @coordsArray.length - @numContourPoints

    if pointCount is 0
      gl.disableVertexAttribArray semantics.POSITION
      return

    gl.uniform4f program.color, 0.7, 0.2, 0.2, 1
    gl.drawArrays gl.POINTS, pointOffset, 1
    if pointCount > 1
      gl.uniform4f program.color, 0, 0, 0, 1
      gl.drawArrays gl.POINTS, pointOffset + 1, pointCount - 1

    if @highlightPoint > -1
      program = @programs.dot
      gl.useProgram program
      gl.uniform1f program.pointSize, 14
      gl.uniform4f program.color, 0, 0, 0, 1
      gl.drawArrays gl.POINTS, @highlightPoint, 1

    gl.disableVertexAttribArray semantics.POSITION

  setPoints: (contourPts, holePts) ->
    @numContourPoints = contourPts.length
    @coordsArray = contourPts.concat holePts
    return if not @coordsArray.length
    typedArray = new Float32Array flatten @coordsArray
    gl.bindBuffer gl.ARRAY_BUFFER, @coordsBuffer
    gl.bufferData gl.ARRAY_BUFFER, typedArray, gl.STATIC_DRAW
    glCheck 'Error when trying to create points VBO'

  setHighlightEdge: (edge) ->
    @highlightEdge = edge
    return if edge is -1
    next = (edge+1) % @coordsArray.length
    typedArray = new Uint16Array [edge, next]
    gl.bindBuffer gl.ELEMENT_ARRAY_BUFFER, @lineBuffer
    gl.bufferData gl.ELEMENT_ARRAY_BUFFER, typedArray, gl.STATIC_DRAW

  setTriangles: (inds) ->
    @indexArray = inds.slice 0
    typedArray = new Uint16Array flatten @indexArray
    gl.bindBuffer gl.ELEMENT_ARRAY_BUFFER, @indexBuffer
    gl.bufferData gl.ELEMENT_ARRAY_BUFFER, typedArray, gl.STATIC_DRAW
    glCheck 'Error when trying to create index VBO'

glCheck = (msg) ->
  console.error(msg) if gl.getError() isnt gl.NO_ERROR

compilePrograms = (shaders) ->
  programs = {}
  for name, shd of shaders
    programs[name] = compileProgram shd.vs, shd.fs, shd.attribs
  programs

compileProgram = (vNames, fNames, attribs) ->
  vShader = compileShader vNames, gl.VERTEX_SHADER
  fShader = compileShader fNames, gl.FRAGMENT_SHADER
  program = gl.createProgram()
  gl.attachShader program, vShader
  gl.attachShader program, fShader
  gl.bindAttribLocation(program, value, key) for key, value of attribs
  gl.linkProgram program
  status = gl.getProgramParameter(program, gl.LINK_STATUS)
  console.error "Could not link #{vNames} with #{fNames}" unless status
  numUniforms = gl.getProgramParameter program, gl.ACTIVE_UNIFORMS
  uniforms = (gl.getActiveUniform(program, u).name for u in [0...numUniforms])
  program[u] = gl.getUniformLocation(program, u) for u in uniforms
  program

compileShader = (names, type) ->
  source = ($('#' + id).text() for id in names).join()
  handle = gl.createShader type
  gl.shaderSource handle, source
  gl.compileShader handle
  status = gl.getShaderParameter handle, gl.COMPILE_STATUS
  console.error gl.getShaderInfoLog(handle) unless status
  handle

loadTexture = (filename) ->
  tex = gl.createTexture()
  tex.image = new Image()
  tex.image.onload = ->
    gl.bindTexture gl.TEXTURE_2D, tex
    gl.pixelStorei gl.UNPACK_FLIP_Y_WEBGL, true
    gl.texImage2D gl.TEXTURE_2D, 0, gl.RGBA, gl.RGBA, gl.UNSIGNED_BYTE, tex.image
    gl.texParameteri gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR
    gl.texParameteri gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR
    gl.bindTexture gl.TEXTURE_2D, null
    glCheck 'Error when loading texture'
  tex.image.src = filename
  tex

module.exports = Display
