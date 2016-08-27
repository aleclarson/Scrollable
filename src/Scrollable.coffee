
{Type, Device, Style, Children} = require "modx"
{NativeValue} = require "modx/native"
{Number} = require "Nan"
{View} = require "modx/views"

emptyFunction = require "emptyFunction"
Rubberband = require "Rubberband"
assertType = require "assertType"
clampValue = require "clampValue"
Draggable = require "Draggable"
isType = require "isType"
Null = require "Null"
bind = require "bind"

Section = require "./Section"

NumberOrNull = Number.or Null

type = Type "Scrollable"

type.defineOptions
  axis: Draggable.Axis.isRequired
  offset: Number
  endThreshold: Number.withDefault 0
  fastThreshold: Number.withDefault 0.2
  stretchLimit: Number
  elasticity: Number.withDefault 0.7
  children: Section.Kind

type.initArgs ([options]) ->

  options.stretchLimit ?=
    if options.axis is "x"
      Device.width
    else Device.height

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

  # The root section that measures any children. (optional)
  _children: null

  # The offset where the content ends.
  # Must know `_visibleLength` and `_contentLength` first.
  _endOffset: null

  # Which index of `_edgeOffsets` is currently exceeded?
  _edgeIndex: null

  # The offset range that represents the scrollable area.
  _edgeOffsets: []

  # The velocity at which scrolling is considered "fast".
  # The `_isScrollingFast` method uses this.
  _fastThreshold: options.fastThreshold

type.defineFrozenValues (options) ->

  _endThreshold: options.endThreshold

  _drag: Draggable
    axis: options.axis
    offset: options.offset
    canDrag: (gesture) => @__canDrag gesture
    shouldCaptureOnStart: (gesture) => @__shouldCaptureOnStart gesture

  _edge: Rubberband
    maxValue: options.stretchLimit
    maxVelocity: 3
    elasticity: options.elasticity

type.initInstance (options) ->
  @children = options.children or null
  return

#
# Prototype-related
#

type.defineEvents

  # Emits when 'offset' is changed.
  didScroll:
    offset: Number

  # Emits when 'endOffset' is changed.
  didLayout: null

  # Emits when 'offset' gets close enough to 'endOffset'.
  didReachEnd: null

type.defineGetters

  axis: -> @_drag.axis

  isHorizontal: -> @_drag.isHorizontal

  gesture: -> @_drag.gesture

  isDragging: -> @_drag.isActive

  contentLength: -> @_contentLength

  visibleLength: -> @_visibleLength

  edgeOffset: ->
    return null if @_edgeIndex is null
    return @_edgeOffsets[@_edgeIndex] or 0

  inBounds: -> @_edgeIndex is null

  isRebounding: -> @_edge.isRebounding

  didDragReject: -> @_drag.didReject

  didDragStart: -> @_drag.didGrant

  didDragEnd: -> @_drag.didEnd

  didTouchStart: -> @_drag.didTouchStart

  didTouchMove: -> @_drag.didTouchMove

  didTouchEnd: -> @_drag.didTouchEnd

type.definePrototype

  children:
    get: -> @_children
    set: (newValue, oldValue) ->
      return if newValue is oldValue

      if oldValue isnt null
        oldValue._index = null
        oldValue._scroll = null
        oldValue._isVisible = null

      if newValue is null
        @_children = null
        return

      assertType newValue, Section.Kind
      newValue._index = 0
      newValue._scroll = this
      newValue._isVisible = yes
      @_children = newValue
      return

  offset:
    get: -> 0 - @_offset.value
    set: (offset) ->
      @_drag.offset.value = 0 - offset

  minOffset:
    get: -> @_edgeOffsets[0] or 0
    set: (minOffset) ->
      @_edgeOffsets[0] = minOffset

  maxOffset:
    get: -> @_edgeOffsets[1] or 0
    set: (maxOffset) ->
      @_edgeOffsets[1] = maxOffset

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

  _animationFlags: ->
    isAnimating: @_drag.offset.isAnimating
    isRebounding: @_edge.isRebounding

  _setContentLength: (newLength) ->
    return if newLength is @_contentLength
    @_updateEndOffset (@_contentLength = newLength), @_visibleLength

  _setVisibleLength: (newLength) ->
    return if newLength is @_visibleLength
    @_updateEndOffset @_contentLength, (@_visibleLength = newLength)

  _updateEndOffset: (contentLength, visibleLength) ->
    newValue = @__computeEndOffset contentLength, visibleLength
    assertType newValue, NumberOrNull
    return if newValue is (oldValue = @_endOffset)
    @_endOffset = newValue
    log.it @__name + ".didLayout()"
    @_events.emit "didLayout"
    return

  _updateReachedEnd: (offset, endOffset) ->
    newValue = @__isEndReached offset, endOffset
    return if @_reachedEnd is newValue
    if @_reachedEnd = newValue
      @_events.emit "didReachEnd"
    return

  _rebound: (velocity) ->
    @stopScrolling()

    if @_edgeIndex is 0
      velocity *= -1

    if velocity > 0
      velocity *= 300

    log.it @__name + "._rebound: {offset: #{@offset}, velocity: #{velocity}}"
    @_edge.rebound {
      velocity
      onEnd: @_onReboundEnd
    }

  _isScrollingFast: ->
    return no if not @__isScrolling()
    return @_fastThreshold < Math.abs @__getVelocity()

  # Since '_drag.offset' isnt updated when '_edge.delta' animates,
  # we need to update '_drag.offset' to match the newest value.
  _getStartOffset: ->
    offset = 0 - @_drag.offset.value
    if @_edgeIndex isnt null
      if @_edgeIndex is 0
        return @edgeOffset - @_edge.resist()
      return @edgeOffset + @_edge.resist()
    return clampValue offset, @minOffset, @maxOffset

type.defineBoundMethods

  _onDragStart: (gesture) ->
    @stopScrolling()
    gesture._startOffset = 0 - @_getStartOffset()
    @__onDragStart gesture
    return

  _onScroll: (offset) ->

    if @inBounds
      @_updateReachedEnd offset, @_endOffset
      @_children and @_children.updateVisibleRange()

    @__onScroll offset
    @_events.emit "didScroll", [offset]

  _onReboundEnd: (finished) ->
    finished and @_edgeIndex = null
    @__onReboundEnd finished

type.defineHooks

  __shouldUpdate: emptyFunction.thatReturnsFalse

  __shouldCaptureOnStart: ->
    if @_edge.isRebounding
      return @_edge.delta > 10
    return @_isScrollingFast()

  __canDrag: emptyFunction.thatReturnsTrue

  __canScroll: ->
    @_endOffset isnt null

  __isScrolling: ->
    @_drag.offset.isAnimating

  __getVelocity: ->
    {animation} = @_drag.offset
    if animation then 0
    else animation.velocity

  __isEndReached: (offset, endOffset) ->
    (endOffset isnt null) and
    (endOffset isnt 0) and
    (endOffset - @_endThreshold <= offset)

  __onDragStart: emptyFunction

  __onDragEnd: (gesture) ->
    return if @inBounds
    {velocity} = gesture
    velocity *= -1 if @_edgeIndex is 0
    @_rebound velocity

  __onScroll: emptyFunction

  __onReboundEnd: emptyFunction

  __computeOffset: (offset, minOffset, maxOffset) ->

    if @_edgeIndex is null
      return clampValue offset, minOffset, maxOffset

    if @_edgeIndex is 0
      return @edgeOffset - @_edge.resist()

    return @edgeOffset + @_edge.resist()

  __computeEndOffset: (contentLength, visibleLength) ->
    return null if contentLength is null
    return null if visibleLength is null
    return Math.max 0, contentLength - visibleLength

#
# View-related
#

type.defineProps
  style: Style
  children: Children

type.defineReactions

  _edgeDelta: ->
    offset = 0 - @_drag.offset.value
    if offset < (minOffset = @minOffset)
      @_edgeIndex = 0
      @_edge.delta = minOffset - offset
    else if offset > (maxOffset = @maxOffset)
      @_edgeIndex = 1
      @_edge.delta = offset - maxOffset
    else
      @_edgeIndex = null
      @_edge.delta = 0
    return

type.defineNativeValues

  _offset: ->
    offset = 0 - @_drag.offset.value
    offset = @__computeOffset offset, @minOffset, @maxOffset
    assertType offset, Number
    return Device.round 0 - offset

  _pointerEvents: ->
    return "auto" if @isTouchable
    return "none"

type.defineListeners ->

  @_offset.didSet @_onScroll

  @_drag.didGrant @_onDragStart

  @_drag.didEnd (gesture) =>
    @__onDragEnd gesture

  @didLayout =>
    @_reachedEnd = no
    @_updateReachedEnd @_offset.value, @_endOffset

type.defineStyles

  container:
    overflow: "hidden"

  contents:
    alignItems: "stretch"
    justifyContent: "flex-start"
    flexDirection: -> if @isHorizontal then "row" else "column"
    translateX: -> @_offset if @isHorizontal
    translateY: -> @_offset if not @isHorizontal

type.render ->
  return View
    style: [ @props.style, @styles.container() ]
    children: @__renderContents()
    pointerEvents: @_pointerEvents
    mixins: [ @_drag.touchHandlers ]
    onLayout: (event) =>
      {layout} = event.nativeEvent
      key = if @isHorizontal then "width" else "height"
      @_setVisibleLength layout[key]

type.defineHooks

  __renderContents: ->

    if @_children
      return @_children.render
        style: @styles.contents()

    return View
      style: @styles.contents()
      children: @props.children
      onLayout: (event) =>
        {layout} = event.nativeEvent
        key = if @isHorizontal then "width" else "height"
        @_setContentLength layout[key]

module.exports = type.build()
