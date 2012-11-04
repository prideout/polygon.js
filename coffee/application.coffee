_mouse =
  position: {x: -1, y: -1}
  within: false
  hot: false
  moved: false

_keys =
  alt: false
  control: false
  shift: false

class Application

  constructor: ->
      @assignEventHandlers()
      @requestAnimationFrame()

  requestAnimationFrame: ->
      onTick = => @tick()
      window.requestAnimationFrame onTick, @canvas

  tick: ->
    @requestAnimationFrame()
    #@display.render()

  onResize: ->
    #tbd

  assignEventHandlers: ->
    events = Backbone.Events
    $(window).resize => @onResize()
    $(document).keydown (e) =>
      _updateKeys e
      switch e.keyCode
        when 38 then events.trigger 'keydown', 'up'
        when 40 then events.trigger 'keydown', 'down'
        when 37 then events.trigger 'keydown', 'left'
        when 39 then events.trigger 'keydown', 'right'
    $('body').mousemove (e) ->
      p = $(this).position()
      x = _mouse.position.x = e.clientX - p.left
      y = _mouse.position.y = e.clientY - p.top
      _mouse.within = 1
      _mouse.moved = true
      _updateKeys e
      events.trigger 'mousemove', x, y, _keys
    $('body').click (e) ->
      p = $(this).position()
      x = _mouse.position.x = e.clientX - p.left
      y = _mouse.position.y = e.clientY - p.top
      _mouse.within = 1
      _updateKeys e
      events.trigger 'click', x, y, _keys
    $('body').mousedown (e) ->
      p = $(this).position()
      x = _mouse.position.x = e.clientX - p.left
      y = _mouse.position.y = e.clientY - p.top
      _mouse.within = 1
      _updateKeys e
      events.trigger 'mousedown', x, y, _keys
    $('body').mouseup (e) ->
      p = $(this).position()
      x = _mouse.position.x = e.clientX - p.left
      y = _mouse.position.y = e.clientY - p.top
      _mouse.within = 1
      _updateKeys e
      events.trigger 'mouseup', x, y, _keys
    $('body').mouseout (e) ->
      _mouse.position.x = -1
      _mouse.position.y = -1
      _mouse.within = false
      _updateKeys e
    $('.home-button').click (e) => @goHomePage()
    $('.unit-button').click (e) => @goUnitPage @CurrentUnit

_updateKeys = (e) ->
  _keys.alt = e.altKey
  _keys.ctrl = e.ctrlKey
  _keys.shift = e.shiftKey
  _keys.lmb = e.which is 1
  _keys.mmb = e.which is 2
  _keys.rmb = e.which is 3

module.exports = Application
