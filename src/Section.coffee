
require "isDev"

{Type, Style} = require "modx"
{View} = require "modx/views"

emptyFunction = require "emptyFunction"
ReactiveList = require "ReactiveList"
assertType = require "assertType"
Promise = require "Promise"
Random = require "random"
Event = require "Event"
sync = require "sync"

SectionHeader = require "./SectionHeader"
ScrollChild = require "./Child"

type = Type "Scrollable_Section"

type.inherits ScrollChild

type.defineOptions
  startIndex: Number.withDefault 0
  endIndex: Number.withDefault 0
  batchSize: Number.withDefault 1
  header: SectionHeader.Kind
  renderHeader: Function
  renderFooter: Function
  renderEmpty: Function

type.defineStatics

  Header: get: -> SectionHeader

type.defineFrozenValues (options) ->

  key: Random.id 8

  didLayout: Event()

  _header: options.header

  __renderHeader: options.renderHeader

  __renderFooter: options.renderFooter

  __renderEmpty: options.renderEmpty

type.defineValues (options) ->

  # TODO: This can be used to keep the number of
  #       rendered children down to a reasonable amount.
  # renderLimit: options.renderLimit

  _batchSize: options.batchSize

  _startIndex: options.startIndex

  _endIndex: options.endIndex

  _rendering: null

  _children: ReactiveList()

  _childElements: []

  _headerElement: null

  _headerLength: null

  _footerElement: no

  _footerLength: null

  _scroll: null

type.defineReactiveValues

  _firstVisibleIndex: null

  _lastVisibleIndex: null

type.defineGetters

  isEmpty: -> @_children.isEmpty

  firstVisibleIndex: -> @_firstVisibleIndex

  lastVisibleIndex: -> @_lastVisibleIndex

  scroll: -> @_scroll

  _isRoot: -> this is @_scroll._section

type.definePrototype

  children:
    get: -> @_children.array
    set: (children) ->
      assertType children, Array
      section = this

      oldChildren = @_children._array
      oldChildren and oldChildren.forEach (child) ->
        section._deinitChild child

      elements = new Array children.length
      children.forEach (child, index) ->
        section._initChild child, index
        elements[index] = no

      @_firstVisibleIndex = null
      @_lastVisibleIndex = null
      @_isRoot and @_scroll._setContentLength null

      @_children.array = children
      @_childElements = elements
      return

  startIndex:
    get: -> @_startIndex
    set: (newValue) ->
      @_children._assertValidIndex newValue
      @_startIndex = newValue

  endIndex:
    get: -> @_endIndex
    set: (newValue) ->
      @_children._assertValidIndex newValue
      @_endIndex = newValue

type.defineMethods

  get: (index) ->
    @_children.get index

  prepend: (children) ->
    if Array.isArray children
      @_prependChildren children
    else @_prependChild children

  append: (children) ->
    if Array.isArray children
      @_appendChildren children
    else @_appendChild children

  # TODO: Support inserting arrays of children.
  insert: (index, child) ->

    assertType index, Number

    isDev and @_children._assertValidIndex index

    children = @_children._array
    sync.repeat numChildren - index, (offset) ->
      children[index + offset]._index += 1

    assertType child, ScrollChild.Kind
    @_initChild child, index

    @_childElements.splice index, 0, no
    @_children.insert index, child
    return

  remove: (index) ->

    assertType index, Number

    isDev and @_children._assertValidIndex index

    children = @_children._array
    sync.repeat @_children.length - index, (offset) ->
      children[startIndex + offset]._index -= 1

    @_childElements.splice index, count
    @_deinitChild @_children.remove index
    return

  setRange: (index, length) ->
    assertType index, Number
    assertType length, Number
    @startIndex = index
    @endIndex = index + length
    return this

  forceUpdate: ->
    @view and @view.forceUpdate()
    return

  # TODO: Support rendering children above the visible region.
  renderWhile: (shouldRender) ->
    return Promise() unless shouldRender()
    maxIndex = @_children._length._value
    return Promise() if @_endIndex is maxIndex
    return @_rendering ?= Promise.defer (resolve) =>

      @_endIndex = Math.max @_endIndex + @_batchSize, maxIndex

      # TODO: Implement trimming to save memory.
      # if (@endIndex - @startIndex) >= @renderLimit
      #   @startIndex -= @_batchSize

      onLayout = @didLayout 1, =>
        @renderWhile shouldRender
          .then resolve

      onLayout.start()
      @forceUpdate()

  renderWhileVisible: ->

    if @_scroll.maxOffset isnt null
      @_renderWhileVisible()
      return

    onLayout = @_scroll
      .didLayout 1, => @_renderWhileVisible()
      .start()
    return

  updateVisibleRange: ->
    startOffset = @_scroll.offset
    endOffset = startOffset + @_scroll.visibleLength
    if @_firstVisibleIndex is null
      @_initVisibleRange startOffset, endOffset
    else @_updateVisibleRange startOffset, endOffset

  _initChild: (child, index) ->

    if child instanceof ScrollSection
      child._scroll = @_scroll

    child._index = index
    child._setSection this
    return

  _deinitChild: (child) ->

    if child instanceof ScrollSection
      child._scroll = null

    child._index = null
    child._setSection null
    return

  _prependChild: (child) ->

    assertType child, ScrollChild.Kind

    # Increment the `index` of every child.
    @_children.forEach (child) ->
      child._index += 1

    @_initChild child, 0

    @_children.prepend child
    @_childElements.unshift no
    return

  _prependChildren: (children) ->
    return unless length = children.length

    # Increment the `index` of every child.
    @_children.forEach (child) ->
      child._index += length

    section = this
    elements = new Array length
    children.forEach (child, index) ->
      assertType child, ScrollChild.Kind
      section._initChild child, index
      elements[index] = no

    @_children.prepend children
    @_childElements = elements.concat @_childElements
    return

  _appendChild: (child) ->

    assertType child, ScrollChild.Kind

    @_initChild child, @_children.length

    @_children.append child
    @_childElements.push no
    return

  _appendChildren: (children) ->
    return unless length = children.length
    offset = @_children.length

    section = this
    elements = new Array length
    children.forEach (child, index) ->
      assertType child, ScrollChild.Kind
      section._initChild child, index + offset
      elements[index] = no

    @_children.append children
    @_childElements = @_childElements.concat elements
    return

  _renderWhileVisible: ->
    scroll = @_scroll
    @renderWhile =>
      return no if @_endIndex is @_children.length
      endLength = scroll.offset + scroll.visibleLength + scroll.visibleThreshold
      return scroll.contentLength < endLength

  _isAreaVisible: (offset, length) ->
    return null if @_scroll.visibleLength is null
    startOffset = @offset
    endOffset = top + @_scroll.visibleLength
    return yes if offset < endOffset
    return offset + length > startOffset

  _getVisibleChildren: ->
    return null if @_firstVisibleIndex is null
    return @_children.array.slice @_firstVisibleIndex, @_lastVisibleIndex + 1

  # Computes the visible range from scratch.
  # TODO: Make this more performant?
  _initVisibleRange: (startOffset, endOffset) ->
    children = @_children._array
    numChildren = @_children.length

    # TODO: Use an `estimatedRowSize` with `startOffset`
    #   to help find the `firstVisibleIndex` faster.
    beforeVisibleRange = yes
    lastVisibleIndex = null

    elements = @_childElements
    index = -1
    while ++index < numChildren
      child = children[index]

      if elements[index] is no
        child._isVisible = no
        continue if beforeVisibleRange
        break

      isHidden =
        if beforeVisibleRange
          (child.offset + child.length) < startOffset
        else child.offset > endOffset

      if isHidden
        child._isVisible = no
        continue if beforeVisibleRange
        break

      child._isVisible = yes
      lastVisibleIndex = index

      if beforeVisibleRange
        beforeVisibleRange = no
        @_firstVisibleIndex = index

    @_firstVisibleIndex = null if beforeVisibleRange
    @_lastVisibleIndex = lastVisibleIndex
    return

  # Updates the visible range using its existing values.
  _updateVisibleRange: (startOffset, endOffset) ->

    if @_firstVisibleIndex is null
      return @_initVisibleRange startOffset, endOffset

    children = @_children._array

    # Find children outside the visible range
    # that are >= the "first visible index".
    index = startIndex = @_firstVisibleIndex
    while child = children[index]
      break if (child.offset + child.length) > startOffset
      @_firstVisibleIndex = index
      index += 1

    # If the "first visible index" did not change...
    if @_firstVisibleIndex is startIndex

      # Find children inside the visible range
      # that are < the "first visible index".
      index = @_firstVisibleIndex - 1
      while child = children[index]
        break if (child.offset + child.length) < startOffset
        @_firstVisibleIndex = index
        index -= 1

    # Find children outside the visible range
    # that are <= the "last visible index".
    index = startIndex = @_lastVisibleIndex
    while child = children[index]
      break if child.offset < endOffset
      @_lastVisibleIndex = index
      index -= 1

    # If the "last visible index" did not change...
    if @_lastVisibleIndex is startIndex

      # Find children inside the visible range
      # that are > the "last visible index".
      index = @_lastVisibleIndex + 1
      while child = children[index]
        break if child.offset > endOffset
        @_lastVisibleIndex = index
        index += 1

    return

  _onLayout: (layout) ->
    {scroll} = this
    @_offset = layout[scroll.axis]
    @_length = layout[if scroll.axis is "x" then "width" else "height"]
    if @_isRoot then scroll._setContentLength @_length
    # else @_isVisible = scroll._isAreaVisible @_offset, @_length
    #   TODO: Update visibility of nested sections.
    @didLayout.emit()

#
# Rendering
#

type.defineProps
  style: Style
  removeClippedSubviews: Boolean.withDefault no # TODO: Should this be `yes`?

type.render ->
  if @isEmpty
    section = @__renderEmpty()
  else
    section = @__renderSection()
  return View
    style: @props.style
    children: section
    removeClippedSubviews: @props.removeClippedSubviews
    onLayout: (event) => @_onLayout event.nativeEvent.layout

type.defineMethods

  _renderHeader: ->
    return @_headerElement ?= View
      children: @__renderHeader()
      onLayout: (event) =>
        {layout} = event.nativeEvent
        @_headerLength = layout[if @scroll.axis is "x" then "width" else "height"]

  _renderChildren: (startIndex, endIndex) ->
    children = @_children._array
    elements = @_childElements

    # TODO: Only iterate the unmounted children?
    offset = -1
    length = endIndex - startIndex
    while ++offset < length
      index = startIndex + offset
      continue if elements[index] isnt no
      elements[index] = children[index].render()

    # TODO: Hide mounted children that are not in the active range?
    return elements

  _renderFooter: ->
    return @_footerElement ?= View
      children: @__renderFooter()
      onLayout: (event) =>
        {layout} = event.nativeEvent
        @_footerLength = layout[if @scroll.axis is "x" then "width" else "height"]

type.defineHooks

  __renderHeader: emptyFunction.thatReturnsFalse

  __renderFooter: emptyFunction.thatReturnsFalse

  __renderEmpty: emptyFunction.thatReturnsFalse

  __renderSection: -> [
    @_renderHeader()
    @_renderChildren @startIndex, @endIndex
    @_renderFooter()
  ]

module.exports = ScrollSection = type.build()
