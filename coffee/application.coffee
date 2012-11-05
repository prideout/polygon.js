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
    $(document).keydown (e) =>
    $('body').mousemove (e) ->
      p = $(this).position()
      x =  e.clientX - p.left
      y = e.clientY - p.top
    $('body').click (e) ->
      p = $(this).position()
      x = e.clientX - p.left
      y = e.clientY - p.top
    $('body').mousedown (e) ->
      p = $(this).position()
      x = e.clientX - p.left
      y = e.clientY - p.top
    $('body').mouseup (e) ->
      p = $(this).position()
      x = e.clientX - p.left
      y = e.clientY - p.top
    $('body').mouseout (e) ->
    $('.home-button').click (e) => @goHomePage()
    $('.unit-button').click (e) => @goUnitPage @CurrentUnit

module.exports = Application
