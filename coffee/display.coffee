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

class Display
  constructor: (context, @width, @height) ->
    gl = context
    @ready = false
    @compilePrograms shaders
    gl.clearColor 0.9, 0.9, 0.9, 1.0

  render: ->
    gl.clear gl.COLOR_BUFFER_BIT

  setPoints: (pts) ->
    console.info 'points:', pts

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
    element = $('#' + name)
    source = (element.text() for name in names)
    source = source.join()
    handle = gl.createShader type
    gl.shaderSource handle, source
    gl.compileShader handle
    status = gl.getShaderParameter handle, gl.COMPILE_STATUS
    console.error gl.getShaderInfoLog(handle) unless status
    handle

module.exports = Display
