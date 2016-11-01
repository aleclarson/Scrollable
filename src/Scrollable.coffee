
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
Event = require "Event"
Null = require "Null"
bind = require "bind"

RootSection = require "./RootSection"

type = Type "Scrollable"

type.defineOptions
  axis: Draggable.Axis.isRequired
  offset: Number
  endThreshold: Number.withDefault 0
  fastThreshold: Number.withDefault 0.2
  stretchLimit: Number
  elasticity: Number.withDefault 0.7

type.initArgs ([options]) ->

  options.stretchLimit ?=
    if options.axis is "x"
      Device.width
    else Device.height

type.defineStatics

  Row: lazy: -> require "./Row"

  Section: lazy: -> require "./Section"

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

type.addMixin Event.Mixin,

  # Emits when 'offset' is changed.
  didScroll: {offset: Number}

  # Emits when 'contentLength' or 'endOffset' is changed.
  didLayout: null

  # Emits when 'offset' gets close enough to 'endOffset'.
  didReachEnd: null

#
# Prototype-related
#

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

  hasChildren: -> @_children isnt null

type.definePrototype

  offset:
    get: -> 0 - @_offset.value
    set: (offset) ->
      @_drag.offset.value = 0 - offset

  minOffset:
    get: -> @_edgeOffsets[0] or 0
    set: (minOffset) ->
      @_edgeOffsets[0] = Device.round minOffset

  maxOffset:
    get: -> @_edgeOffsets[1] or 0
    set: (maxOffset) ->
      @_edgeOffsets[1] = Device.round maxOffset

  isTouchable:
    get: -> @_touchable
    set: (isTouchable) ->
      @_touchable = isTouchable

type.defineMethods

  createChildren: ->

    if @_children
      throw Error "'createChildren' cannot be called more than once!"

    @_children = RootSection {scroll: this}

  scrollTo: (offset, config) ->
    assertType offset, Number
    assertType config, Object
    config.endValue = 0 - offset
    # if isType config.velocity, Number
    #   config.velocity = 0 - config.velocity
    return @_drag.offset.animate config

  stopScrolling: ->
    @_drag.offset.stopAnimation()
    @_edge.isRebounding and @_edge.stopRebounding()
    return

  _onLayout: ->
    @_reachedEnd = no
    @_updateReachedEnd @_offset.value, @_endOffset
    @__events.didLayout()
    return

  _setContentLength: (newLength) ->
    return if newLength is @_contentLength
    @_contentLength = newLength
    @_updateEndOffset newLength, @_visibleLength
    @_onLayout()
    return

  _setVisibleLength: (newLength) ->
    return if newLength is @_visibleLength
    @_visibleLength = newLength
    @_onLayout() if @_updateEndOffset @_contentLength, newLength
    return

  _updateEndOffset: (contentLength, visibleLength) ->
    endOffset = null

    if (contentLength isnt null) and (visibleLength isnt null)
      endOffset = @__computeEndOffset contentLength, visibleLength
      assertType endOffset, Number.or Null

    if endOffset isnt @_endOffset
      @_endOffset = endOffset
      return yes
    return no

  _updateReachedEnd: (offset, endOffset) ->
    newValue = @__isEndReached offset, endOffset
    return if @_reachedEnd is newValue
    if @_reachedEnd = newValue
      @__events.didReachEnd()
    return

  _rebound: (velocity) ->
    @stopScrolling()

    if @_edgeIndex is 0
      velocity *= -1

    if velocity > 0
      velocity *= 300

    @_edge.rebound {
      velocity
      onUpdate: @_reboundDidUpdate
      onEnd: @_reboundDidEnd
    }

  _isScrollingFast: ->
    return no if not @__isScrolling()
    return @_fastThreshold < Math.abs @__getVelocity()

  # Find the necessary value of '_drag.offset' that equals
  # the current 'offset' after '_edge.resist()' is applied.
  _computeRawOffset: ->
    if @_edgeIndex isnt null
      if @_edgeIndex is 0
        return @edgeOffset - @_edge.resist()
      return @edgeOffset + @_edge.resist()
    return clampValue 0 - @_drag.offset.value, @minOffset, @maxOffset

  _updateEdgeOffsets: ->
    @_edgeOffsets = [
      Device.round @__computeMinOffset()
      Device.round @__computeMaxOffset()
    ]
    return

  _isChildVisible: (child) ->
    {section, offset} = child

    visibleStart = @offset
    visibleEnd = visibleStart + @visibleLength
    while section isnt null
      return no if section.inVisibleArea is no
      offset += section.startOffset
      return no if offset > visibleEnd
      section = section.section

    endOffset = offset + child.length
    return no if endOffset < visibleStart
    return {
      startOffset: Math.max visibleStart, offset
      endOffset: Math.min visibleEnd, endOffset
    }

type.defineBoundMethods

  _dragDidStart: (gesture) ->
    @stopScrolling()
    gesture._startOffset = 0 - @_computeRawOffset()
    @__dragDidStart gesture
    return

  _offsetDidChange: (offset) ->

    if @inBounds
      @_updateReachedEnd offset, @_endOffset
      # @_children and @_children.updateVisibleRange()

    @__offsetDidChange offset
    @__events.didScroll offset
    return

  _reboundDidUpdate: (offset) ->
    @__reboundDidUpdate offset
    return

  _reboundDidEnd: (finished) ->
    finished and @_edgeIndex = null
    @__reboundDidEnd finished
    return

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

  __dragDidStart: emptyFunction

  __dragDidMove: emptyFunction

  __dragDidEnd: (gesture) ->
    return if @inBounds
    {velocity} = gesture
    velocity *= -1 if @_edgeIndex is 0
    @_rebound velocity

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

  __computeMinOffset: ->
    return 0

  __computeMaxOffset: ->
    return 0 if @_endOffset is null
    return 0 if @visibleLength is null
    return Math.max 0, @_endOffset - @visibleLength

  __offsetDidChange: emptyFunction

  __reboundDidUpdate: emptyFunction

  __reboundDidEnd: emptyFunction

  __childWillAttach: emptyFunction.thatReturnsArgument

  __childDidAttach: emptyFunction

  __childWillDetach: emptyFunction

  __childWillMount: emptyFunction

  __childDidLayout: emptyFunction

  __childDidReveal: emptyFunction

  __childDidConceal: emptyFunction

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

  @_offset.didSet @_offsetDidChange

  @_drag.didGrant @_dragDidStart

  @_drag.didTouchMove (gesture) =>
    @__dragDidMove gesture

  @_drag.didEnd (gesture) =>
    @__dragDidEnd gesture

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

  __renderHeader: emptyFunction.thatReturnsFalse

  __renderFooter: emptyFunction.thatReturnsFalse

  __renderEmpty: emptyFunction.thatReturnsFalse

  __renderOverlay: emptyFunction.thatReturnsFalse

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
