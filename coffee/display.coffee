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

  compilePrograms: ->
    for name, metadata of root.shaders
      continue if name == "source"
      [vs, fs] = metadata.keys
      @programs[name] = @compileProgram vs, fs, metadata.attribs, metadata.uniforms

  compileProgram: (vName, fName, attribs, uniforms) ->
    vShader = @compileShader vName, gl.VERTEX_SHADER
    fShader = @compileShader fName, gl.FRAGMENT_SHADER
    program = gl.createProgram()
    gl.attachShader program, vShader
    gl.attachShader program, fShader
    gl.bindAttribLocation(program, value, key) for key, value of attribs
    gl.linkProgram program
    status = gl.getProgramParameter(program, gl.LINK_STATUS)
    console.error "Could not link #{vName} with #{fName}") unless status
    numUniforms = gl.getProgramParameter program, gl.ACTIVE_UNIFORMS
    uniforms = (gl.getActiveUniform(program, u).name for u in [0...numUniforms])
    program[u] = gl.getUniformLocation(program, u) for u in uniforms
    program

  compileShader: (name, type) ->
    source = root.shaders.source[name]
    handle = gl.createShader type
    gl.shaderSource handle, source
    gl.compileShader handle
    status = gl.getShaderParameter handle, gl.COMPILE_STATUS
    console.error gl.getShaderInfoLog(handle)} unless status
    handle

module.exports = Display
