Display = require './display'

class Application

  constructor: ->
      try
        c = $('canvas').get 0
        gl = c.getContext 'experimental-webgl', antialias: true
        throw new Error() if not gl
      catch error
        msg = 'Alas, your browser does not support WebGL.'
        $('canvas').replaceWith "<p class='error'>#{msg}</p>"

      if gl
        width = parseInt $('canvas').css('width')
        height = parseInt $('canvas').css('height')
        @display = new Display(gl, width, height)

      @assignEventHandlers()
      @requestAnimationFrame()

  requestAnimationFrame: ->
      onTick = => @tick()
      window.requestAnimationFrame onTick, @canvas

  tick: ->
    @requestAnimationFrame()
    @display?.render()

  onResize: ->
    #tbd

  assignEventHandlers: ->
    $(window).resize => @onResize()

    # (0,0) is upper-left corner.
    $('canvas').click (e) ->
      p = $(this).position()
      x = e.offsetX
      y = e.offsetY
      console.info x, y

module.exports = Application
