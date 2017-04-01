
{Style, Children} = require "react-validators"

TouchHistoryMath = require "react-native/lib/TouchHistoryMath"
TouchHistory = require "react-native/lib/TouchHistory"

normalizeNativeEvent = require "normalizeNativeEvent"
findNodeHandle = require "react/lib/findNodeHandle"
Velocity = require "Velocity"
View = require "modx/lib/View"
modx = require "modx"

ScrollFocus = require "./ScrollFocus"

type = modx.Type "Scrollable"

type.defineProps
  style: Style
  children: Children

type.render ->
  return View
    ref: @_onRef
    style: @props.style
    children: @props.children
    onScroll: @_onScroll

type.initInstance ->
  global.scroller = this

type.defineValues

  _node: null

  _touchHistory: new TouchHistory

  _scrolling: no

  _endTimeout: null

type.createValue "_velocity", -> Velocity()

type.defineGetters

  isDragging: -> @_touchHistory.numberActiveTouches > 0

  isScrolling: -> @_scrolling

type.defineMethods

  focus: ->
    ScrollFocus.set @_node
    return

type.defineBoundMethods

  _onRef: (ref) ->
    if ref is null
      node = @_node
      @_node = null
      node.removeEventListener "touchstart", @_onTouchStart
      node.removeEventListener "touchmove", @_onTouchMove
      node.removeEventListener "touchend", @_onTouchEnd
    else
      @_node = node = findNodeHandle ref
      node.addEventListener "touchstart", @_onTouchStart
      node.addEventListener "touchmove", @_onTouchMove
      node.addEventListener "touchend", @_onTouchEnd
      Object.assign node.style, scrollStyle
      node.scrollTop = 1
    return

  _onTouchStart: (event) ->
    event = normalizeNativeEvent event

    lastCount = @_touchHistory.numberActiveTouches
    @_touchHistory.recordTouchEvent "topTouchStart", event.changedTouches
    return if lastCount > 1

    if @_scrolling
      @_scrolling = no
      clearTimeout @_endTimeout
      @_endTimeout = null
      avoidEdges @_node

    @_velocity.reset()
    return

  _onTouchMove: (event) ->
    event = normalizeNativeEvent event
    @_touchHistory.recordTouchEvent "topTouchMove", event.changedTouches
    @_velocity.update Date.now(), TouchHistoryMath.currentCentroidY @_touchHistory
    return

  _onTouchEnd: (event) ->
    event = normalizeNativeEvent event

    @_touchHistory.recordTouchEvent "topTouchEnd", event.changedTouches
    return if @_touchHistory.numberActiveTouches > 0

    @_scrolling = shouldRebound(@_node) or @_velocity.get() isnt 0
    return

  _onScroll: ->
    if @_scrolling
      clearTimeout @_endTimeout
      @_endTimeout = setTimeout @_onScrollEnd, 150
    return

  _onScrollEnd: ->
    if @_scrolling
      @_scrolling = no
      @_endTimeout = null
      avoidEdges @_node
    return

module.exports = type.build()

scrollStyle =
  overflowY: "scroll"
  webkitOverflowScrolling: "touch"

getMaxOffset = (node) ->
  node.scrollHeight - node.offsetHeight

# Returns true if `node.scrollTop` is past one of its edges.
shouldRebound = (node) ->
  return yes if node.scrollTop < 0
  return node.scrollTop > getMaxOffset node

# Prevent `node.scrollTop` from being directly on the edge.
# Otherwise, the user ends up scrolling `document.body` instead.
avoidEdges = (node) ->

  if node.scrollTop is 0
    node.scrollTop = 1
    return

  maxOffset = getMaxOffset node
  if node.scrollTop is maxOffset
    node.scrollTop = maxOffset - 1
    return
