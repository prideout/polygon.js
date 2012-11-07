gl = null

semantics =
  POSITION : 0
  VERTEXID : 0
  NORMAL   : 1
  TEXCOORD : 2

shaders = {}

shaders.basic =
  vs: ['basicvs']
  fs: ['basicfs']
  attribs:
    Position: semantics.POSITION

glCheck = (msg) ->
  console.error(msg) if gl.getError() isnt gl.NO_ERROR

class Display
  constructor: (context, @width, @height) ->
    gl = context
    @compilePrograms shaders
    @loadTextures()
    @coordsArray = []
    @coordsBuffer = gl.createBuffer()
    gl.clearColor 0.9, 0.9, 0.9, 1.0
    gl.lineWidth 2

  render: ->
    gl.clear gl.COLOR_BUFFER_BIT

    return if @coordsArray.length is 0

    program = @programs.basic
    gl.useProgram program
    gl.uniform4f program.color, 1, 0, 0, 1

    mv = new mat4()

    proj = new mat4()
    proj.makeOrthographic(0, 600, 0, 600, 0, 1)

    gl.uniformMatrix4fv program.modelview, false, mv.elements
    gl.uniformMatrix4fv program.projection, false, proj.elements

    gl.bindBuffer gl.ARRAY_BUFFER, @coordsBuffer
    gl.enableVertexAttribArray semantics.POSITION
    gl.vertexAttribPointer semantics.POSITION, 2, gl.FLOAT, false, stride = 8, 0
    gl.drawArrays gl.POINTS, 0, @coordsArray.length
    gl.disableVertexAttribArray semantics.POSITION

  setPoints: (pts) ->
    @coordsArray = pts.slice 0
    typedArray = new Float32Array flatten @coordsArray
    gl.bindBuffer gl.ARRAY_BUFFER, @coordsBuffer
    gl.bufferData gl.ARRAY_BUFFER, typedArray, gl.STATIC_DRAW
    glCheck "Error when trying to create VBO"
    console.info "#{pts.length} points received: ", typedArray

  loadTextures: ->
    tex = gl.createTexture()
    tex.image = new Image()
    tex.image.onload = ->
      gl.bindTexture gl.TEXTURE_2D, tex
      gl.pixelStorei gl.UNPACK_FLIP_Y_WEBGL, true
      gl.texImage2D gl.TEXTURE_2D, 0, gl.RGBA, gl.RGBA, gl.UNSIGNED_BYTE, tex.image
      gl.texParameteri gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.NEAREST
      gl.texParameteri gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.NEAREST
      gl.bindTexture gl.TEXTURE_2D, null
      glCheck "Load texture"
      console.info "prideout texture laoded"
    tex.image.src = 'textures/PointSprite.png'
    @pointSprite = tex

  compilePrograms: (shaders) ->
    @programs = {}
    for name, shd of shaders
      @programs[name] = @compileProgram shd.vs, shd.fs, shd.attribs

  compileProgram: (vNames, fNames, attribs) ->
    vShader = @compileShader vNames, gl.VERTEX_SHADER
    fShader = @compileShader fNames, gl.FRAGMENT_SHADER
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

  compileShader: (names, type) ->
    source = ($('#' + id).text() for id in names).join()
    handle = gl.createShader type
    gl.shaderSource handle, source
    gl.compileShader handle
    status = gl.getShaderParameter handle, gl.COMPILE_STATUS
    console.error gl.getShaderInfoLog(handle) unless status
    handle

module.exports = Display
