
# TODO: Add 'estimatedRowSize' for computing 'estimatedTotalSize'?

{screenWidth, screenHeight, roundToScreenScale} = require "device"
{Component, NativeValue} = require "modx"

emptyFunction = require "emptyFunction"
Rubberband = require "Rubberband"
Draggable = require "Draggable"

type = Component.Type "VirtualScroll"

type.defineOptions
  axis: Draggable.Axis.isRequired
  offset: Number
  maxOffset: Number
  endThreshold: Number.withDefault 0
  elasticity: Number.withDefault 0.7
  stretchLimit: Number

type.defineFrozenValues

  _endThreshold: fromArgs "endThreshold"

  _offset: ->
    NativeValue =>
      @_computeOffset()

  _pointerEvents: -> NativeValue =>
    return "auto" if @isTouchable
    return "none"

  _drag: (options) ->
    return Draggable
      axis: options.axis
      offset: options.offset
      inverse: yes
      canDrag: (gesture) => @__canDrag gesture
      shouldCaptureOnStart: @_shouldCaptureOnStart

type.defineReactiveValues

  _touchable: yes

  _edgeOffset: null

  _visibleLength: null

  _contentLength: null

  _reachedEnd: no

type.defineValues

  _maxOffset: (options) ->
    options.maxOffset ?= null

  _edge: (options) ->
    options.stretchLimit ?= @_defaultStretchLimit
    return Rubberband
      elasticity: options.elasticity
      maxValue: options.stretchLimit

type.defineEvents

  didLayout: { maxOffset: Number, oldMaxOffset: Number }

  didScroll: { offset: Number }

  didReachEnd: null

type.defineGetters

  axis: -> @_drag.axis

  gesture: -> @_drag.gesture

  isDragging: -> @_drag.isActive

  minOffset: -> 0

  maxOffset: -> @_maxOffset

  inBounds: -> @_edge.distance is 0

  isRebounding: -> @_edge.isRebounding

  didDragReject: -> @_drag.didReject

  didDragStart: -> @_drag.didGrant

  didDragEnd: -> @_drag.didEnd

  didTouchStart: -> @_drag.didTouchStart

  didTouchMove: -> @_drag.didTouchMove

  didTouchEnd: -> @_drag.didTouchEnd

  _defaultStretchLimit: ->
    if @axis is "x"
      return screenWidth.get()
    return screenHeight.get()

type.definePrototype

  offset:
    get: -> @_offset.value
    set: (offset) ->
      @_drag.offset.value = offset

  contentLength:
    get: -> @_contentLength
    set: (newLength, oldLength) ->
      return if newLength is oldLength
      @_contentLength = newLength
      @_updateMaxOffset()

  visibleLength:
    get: -> @_visibleLength
    set: (newLength, oldLength) ->
      return if newLength is oldLength
      @_visibleLength = newLength
      @_updateMaxOffset()

  isTouchable:
    get: -> @_touchable
    set: (isTouchable) ->
      @_touchable = isTouchable

type.defineMethods

  scrollTo: (offset, config) ->
    assertType offset, Number
    assertType config, Object
    config.endValue = offset
    return @_drag.offset.animate config

  stopScrolling: ->
    @_drag.offset.stopAnimation()
    @_edge.isRebounding and @_edge.stopRebounding()
    return

  _computeOffset: ->
    offset = @_drag.offset.value
    @_edgeOffset = @_getEdgeOffset offset, @maxOffset
    if not @inBounds
      if @_edgeOffset is @maxOffset
        @_edge.offset = offset - @maxOffset
        offset = @_edgeOffset + @_edge.distance
      else
        @_edge.offset = @minOffset - offset
        offset = @_edgeOffset - @_edge.distance
    return roundToScreenScale offset

  _getEdgeOffset: (offset, maxOffset) ->
    return @minOffset if offset < @minOffset
    return maxOffset if offset > maxOffset
    return null

  _updateMaxOffset: ->

    newValue = null
    if @contentLength? and @visibleLength?
      newValue = Math.max 0, @contentLength - @visibleLength

    oldValue = @_maxOffset
    return if newValue is oldValue
    @_maxOffset = newValue

    @_reachedEnd = no
    @_updateReachedEnd @_offset.value
    @_events.emit "didLayout", [newValue, oldValue]

  _updateReachedEnd: ->
    maxOffset = @_maxOffset
    newValue = @__isEndReached()
    return if @_reachedEnd is newValue
    if @_reachedEnd = newValue
      @_events.emit "didReachEnd"
    return

  _shouldRebound: (velocity) ->
    return no if @inBounds
    return @__shouldRebound velocity

type.defineBoundMethods

  _shouldCaptureOnStart: (gesture) ->

    # When scrolling fast enough, capture the active touch.
    if @__isScrolling gesture
      { velocity } = @_drag.offset.animation
      return Math.abs(velocity) > 0.02

    # When rebounding, capture the active touch (unless the rebound is almost finished).
    if @_edge.isRebounding
      return @_edge.distance > 10

    return @__shouldCaptureOnStart gesture

  _onScroll: (offset) ->
    log.it @__name + "._onScroll: " + offset
    @inBounds and @_updateReachedEnd offset, @maxOffset
    @__onScroll offset, @maxOffset
    return

  _onDragStart: (gesture) ->
    @stopScrolling()
    @__onDragStart gesture
    return

  _onDragEnd: (gesture) ->

    velocity = gesture.velocity

    if @_shouldRebound velocity
      @_edge.rebound velocity
      return

    @__onDragEnd velocity, gesture
    return

type.defineHooks

  __shouldUpdate: emptyFunction.thatReturnsFalse

  __shouldCaptureOnStart: emptyFunction.thatReturnsFalse

  __canDrag: emptyFunction.thatReturnsTrue

  __canScroll: ->
    @_maxOffset isnt null

  __isScrolling: ->
    @_drag.offset.isAnimating

  __isEndReached: (offset, maxOffset) ->
    (maxOffset isnt null) and
    (maxOffset isnt 0) and
    (maxOffset - @_endThreshold <= offset)

  __onScroll: (offset) ->
    @_events.emit "didScroll", [offset]

  __onDragStart: emptyFunction

  __onDragEnd: emptyFunction

  __shouldRebound: emptyFunction.thatReturnsTrue

type.defineListeners ->

  @_offset.didSet @_onScroll

  @_drag.didGrant @_onDragStart

  @_drag.didEnd @_onDragEnd

type.defineStyles

  content:
    alignItems: "stretch"
    justifyContent: "flex-start"
    flexDirection: -> if @axis is "x" then "row" else "column"
    translateX: -> @_offset if @axis is "x"
    translateY: -> @_offset if @axis is "y"

  container:
    overflow: "hidden"

type.willUnmount ->
  @visibleLength = null
  @contentLength = null

type.render ->
  return View
    style: @styles.container()
    children: @__renderContent()
    pointerEvents: @_pointerEvents
    mixins: [ @_drag.touchHandlers ]
    onLayout: (event) =>
      {layout} = event.nativeEvent
      key = if @axis is "x" then "width" else "height"
      @visibleLength = layout[key]

type.defineHooks

  __renderChildren: emptyFunction

  __renderContent: ->
    return View
      children: @__renderChildren()
      onLayout: (event) =>
        {layout} = event.nativeEvent
        key = if @axis is "x" then "width" else "height"
        @contentLength = layout[key]

module.exports = type.build()
