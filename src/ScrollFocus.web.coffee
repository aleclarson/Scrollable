
TimingAnimation = require "TimingAnimation"
roundValue = require "roundValue"
Easing = require "easing"
Device = require "modx/lib/Device"
isNode = require "fbjs/lib/isNode"
Type = require "Type"

{body} = document

type = Type "ScrollFocus"

type.defineValues ->

  _focused: null

  _underTop: no

  _touchCount: 0

  _scrolling: no

  _prevented: no

  _animated: @_createAnimated()

type.initInstance ->
  @_makeBodyScrollable()
  requestAnimationFrame =>
    @_disableScrollToTop()
    window.addEventListener "scroll", @_scrollToTop

type.defineMethods

  set: (node) ->

    if @_focused
      throw Error "Another node is already focused!"

    unless isNode node
      throw Error "Expected a DOM node!"

    @_focused = node
    @_computeUnderTop()
    node.addEventListener "scroll", @_onScroll
    node.addEventListener "touchstart", @_onTouchStart
    node.addEventListener "touchend", @_onTouchEnd
    return

  reset: ->
    if node = @_focused
      node.removeEventListener "scroll", @_onScroll
      node.removeEventListener "touchstart", @_onTouchStart
      node.removeEventListener "touchend", @_onTouchEnd
      @_focused = null
      @_underTop = no
      @_touchCount = 0
      @_disableScrollToTop()
      return

  # Creates a mock `Animated` instance to use with `Animation` instances.
  _createAnimated: ->
    _animation: null
    _updateValue: @_updateValue

  # Append an element to `document.body` that makes it scrollable.
  _makeBodyScrollable: ->

    div = document.createElement "div"
    Object.assign div.style,
      width: "1px"
      height: "#{Device.height + 1}px"
      visibility: "hidden"
      pointerEvents: "none"

    body.appendChild div
    return

  _shouldScroll: ->
    return @_prevented = no if @_prevented
    return no if @_touchCount > 0
    return @_underTop and not @_scrolling

  # Prevent tapping the status bar from triggering `_scrollToTop`.
  _disableScrollToTop: ->
    if body.scrollTop isnt 0
      @_prevented = yes
      body.scrollTop = 0
    return

  # The `_scrollToTop` animation is ruined if we don't stop native scrolling.
  _stopNativeScrolling: ->
    {style} = @_focused

    style.overflowY = "hidden"
    allowScrolling = ->
      # Prevent flicker by waiting for next animation frame.
      requestAnimationFrame ->
        style.overflowY = "scroll"
        return

    # Scroll momentum is not prevented unless we delay.
    setTimeout allowScrolling, 100
    return

  # Allows `_scrollToTop` if the focused `node.scrollTop` is greater than 1.
  _computeUnderTop: ->

    if @_scrolling
      throw Error "Cannot compute '_underTop' while scrolling to top!"

    oldValue = @_underTop
    newValue = @_focused.scrollTop > 1

    if newValue isnt oldValue
      @_underTop = newValue
      @_prevented = yes
      body.scrollTop = if newValue then 1 else 0
    return

type.defineBoundMethods

  _updateValue: (value) ->
    node = @_focused
    value = roundValue value, 1
    if node.scrollTop isnt value
      node.scrollTop = value
    return

  _onScroll: (event) ->
    unless @_scrolling
      @_computeUnderTop()
    return

  _onTouchStart: (event) ->

    lastCount = @_touchCount
    @_touchCount += event.changedTouches.length
    return if lastCount > 0

    if @_scrolling
      event.stopPropagation()
      @_animated._animation.stop()
    return

  _onTouchEnd: (event) ->
    @_touchCount -= event.changedTouches.length
    return

  _scrollToTop: ->
    return unless @_shouldScroll()
    @_stopNativeScrolling()
    @_scrolling = yes
    @_underTop = no

    animation = TimingAnimation
      duration: 1000
      fromValue: @_focused.scrollTop
      toValue: 1
      easing: Easing.outQuad

    animation.start @_animated
    animation.then (finished) =>
      @_scrolling = no
      @_computeUnderTop()
      return

module.exports = type.construct()
