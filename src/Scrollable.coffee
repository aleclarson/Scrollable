
{Type, Device, Element, Children} = require "modx"
{NativeValue} = require "modx/native"
{View} = require "modx/views"

emptyFunction = require "emptyFunction"
Rubberband = require "Rubberband"
assertType = require "assertType"
clampValue = require "clampValue"
Draggable = require "Draggable"
ArrayOf = require "ArrayOf"
isType = require "isType"
Null = require "Null"
Nan = require "Nan"

Section = require "./Section"

type = Type "Scrollable"

type.defineOptions
  axis: Draggable.Axis.isRequired
  offset: Number
  endThreshold: Number.withDefault 0
  visibleThreshold: Number.withDefault 0
  stretchLimit: Number
  elasticity: Number.withDefault 0.7
  section: Section

type.defineStatics

  Section: get: -> Section

  Row: lazy: -> require "./Row"

  Child: lazy: -> require "./Child"

type.defineReactiveValues

  _touchable: yes

  _visibleLength: null

  _contentLength: null

  _reachedEnd: no

type.defineValues (options) ->

  visibleThreshold: options.visibleThreshold

  _section: null

  _edgeOffset: null

  _maxOffset: null

  __renderContents: if options.section then @_renderSection

type.defineFrozenValues (options) ->

  _endThreshold: options.endThreshold

  _drag: Draggable
    axis: options.axis
    offset: options.offset
    canDrag: (gesture) => @__canDrag gesture
    shouldCaptureOnStart: @_shouldCaptureOnStart

  _edge: Rubberband
    maxValue: options.stretchLimit ?= @_getDefaultStretchLimit options.axis
    elasticity: options.elasticity

type.initInstance (options) ->
  @section = options.section or null
  return

#
# Prototype-related
#

type.defineEvents

  didLayout:
    newValue: [ Number, Null ]
    oldValue: [ Number, Null ]

  didScroll:
    offset: Number

  didReachEnd: null

type.defineGetters

  axis: -> @_drag.axis

  gesture: -> @_drag.gesture

  isDragging: -> @_drag.isActive

  minOffset: -> 0

  maxOffset: -> @_maxOffset

  contentLength: -> @_contentLength

  visibleLength: -> @_visibleLength

  inBounds: -> @_edge.delta is 0

  isRebounding: -> @_edge.isRebounding

  didDragReject: -> @_drag.didReject

  didDragStart: -> @_drag.didGrant

  didDragEnd: -> @_drag.didEnd

  didTouchStart: -> @_drag.didTouchStart

  didTouchMove: -> @_drag.didTouchMove

  didTouchEnd: -> @_drag.didTouchEnd

type.definePrototype

  section:
    get: -> @_section
    set: (section) ->

      if oldValue = @_section
        return if oldValue is section
        section._isVisible = null
        section._index = null
        section._scroll = null

      if section
        section._isVisible = yes
        section._index = 0
        section._scroll = this
        @_section = section

  offset:
    get: -> 0 - @_offset.value
    set: (offset) ->
      @_drag.offset.value = 0 - offset

  isTouchable:
    get: -> @_touchable
    set: (isTouchable) ->
      @_touchable = isTouchable

type.defineMethods

  scrollTo: (offset, config) ->
    assertType offset, Number
    assertType config, Object
    config.endValue = 0 - offset
    return @_drag.offset.animate config

  stopScrolling: ->
    @_drag.offset.stopAnimation()
    @_edge.isRebounding and @_edge.stopRebounding()
    return

  _setContentLength: (newLength) ->
    oldLength = @_contentLength
    return if newLength is oldLength
    @_contentLength = newLength
    @_updateMaxOffset()

  _setVisibleLength: (newLength) ->
    oldLength = @_visibleLength
    return if newLength is oldLength
    @_visibleLength = newLength
    @_updateMaxOffset()

  _updateMaxOffset: ->

    newValue = null
    if @contentLength? and @visibleLength?
      newValue = Math.max 0, @contentLength - @visibleLength

    oldValue = @_maxOffset
    return if newValue is oldValue
    @_maxOffset = newValue

    @_reachedEnd = no
    @_updateReachedEnd @_offset.value, newValue
    @_events.emit "didLayout", [newValue, oldValue]

  _updateReachedEnd: (offset, maxOffset) ->
    newValue = @__isEndReached offset, maxOffset
    return if @_reachedEnd is newValue
    if @_reachedEnd = newValue
      @_events.emit "didReachEnd"
    return

  _shouldRebound: (gesture) ->
    return no if @inBounds
    return @__shouldRebound gesture

  _rebound: ({velocity}) ->
    maxOffset = @_maxOffset or 0
    velocity *= -1 if @offset > maxOffset
    @_edge.rebound velocity

  _getDefaultStretchLimit: (axis) ->
    return Device.width if axis is "x"
    return Device.height

type.defineBoundMethods

  _shouldCaptureOnStart: (gesture) ->

    # When rebounding, capture the active touch (unless the rebound is almost finished).
    if @_edge.isRebounding
      log.it "edge.delta = " + @_edge.delta
      return @_edge.delta > 10

    # When scrolling fast enough, capture the active touch.
    if @__isScrolling gesture
      { velocity } = @_drag.offset.animation
      return Math.abs(velocity) > 0.02

    return @__shouldCaptureOnStart gesture

  _onScroll: (offset) ->
    maxOffset = @_maxOffset or 0
    if @inBounds
      @_updateReachedEnd offset, maxOffset
      @_section and @_section._getVisibleRange()
    @__onScroll offset, maxOffset
    @_events.emit "didScroll", [offset]

  _onDragStart: (gesture) ->
    @stopScrolling()

    # Since '_drag.offset' isnt updated when '_edge.delta' animates,
    # we need to update '_drag.offset' to match the newest value.
    offset = 0 - @_drag.offset.value
    delta = @_edge.delta
    if delta > 0
      delta *= -1 if offset < @minOffset
      offset = @_edgeOffset + delta
    else
      offset = clampValue offset, @minOffset, @_maxOffset or 0

    offset *= -1
    @_drag.offset._value =
      gesture._startOffset = offset

    @__onDragStart gesture
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

  __onDragStart: emptyFunction

  __onDragEnd: (gesture) ->
    if @_shouldRebound gesture
      @_rebound gesture

  __shouldRebound: emptyFunction.thatReturnsTrue

  __onScroll: emptyFunction

  __computeOffset: (offset, minOffset, maxOffset) ->
    if @_edgeOffset is null
      return clampValue offset, minOffset, maxOffset
    delta = @_edge.resist()
    delta *= -1 if offset < minOffset
    return @_edgeOffset + delta

#
# View-related
#

type.propTypes =
  children: Children

type.defineNativeValues ->

  _edgeDelta: =>
    offset = 0 - @_drag.offset.value
    if offset < (minOffset = @minOffset)
      @_edgeOffset = minOffset
      @_edge.delta = minOffset - offset
    else if offset > (maxOffset = @_maxOffset or 0)
      @_edgeOffset = maxOffset
      @_edge.delta = offset - maxOffset
    else
      @_edgeOffset = null
      @_edge.delta = 0
    return

  _offset: =>

    offset = 0 - @_drag.offset.value
    minOffset = @minOffset
    maxOffset = @_maxOffset or 0

    offset = @__computeOffset offset, minOffset, maxOffset

    if Nan.test offset
      throw Error "Unexpected NaN value!"

    if not isType offset, Number
      throw TypeError "'__computeOffset' must return a Number!"

    return Device.round 0 - offset

  _pointerEvents: =>
    return "auto" if @isTouchable
    return "none"

type.defineListeners ->

  @_offset.didSet @_onScroll

  @_drag.didGrant @_onDragStart

  @_drag.didEnd (gesture) =>
    @__onDragEnd gesture

type.defineStyles

  contents:
    alignItems: "stretch"
    justifyContent: "flex-start"
    flexDirection: -> if @axis is "x" then "row" else "column"
    translateX: -> @_offset if @axis is "x"
    translateY: -> @_offset if @axis is "y"

  container:
    overflow: "hidden"

type.render ->
  return View
    style: @styles.container()
    children: @__renderContents()
    pointerEvents: @_pointerEvents
    mixins: [ @_drag.touchHandlers ]
    onLayout: (event) =>
      {layout} = event.nativeEvent
      key = if @axis is "x" then "width" else "height"
      @_setVisibleLength layout[key]

type.defineMethods

  _renderSection: ->
    return @_section.render
      style: @styles.contents()

type.defineHooks

  __renderContents: ->
    return View
      style: @styles.contents()
      children: @props.children
      onLayout: (event) =>
        {layout} = event.nativeEvent
        key = if @axis is "x" then "width" else "height"
        @_setContentLength layout[key]

module.exports = type.build()
