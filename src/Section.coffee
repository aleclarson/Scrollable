
require "isDev"

{Type, Style} = require "modx"
{View} = require "modx/views"

emptyFunction = require "emptyFunction"
assertType = require "assertType"
clampValue = require "clampValue"
fromArgs = require "fromArgs"
LazyVar = require "LazyVar"
Promise = require "Promise"
Random = require "random"
assert = require "assert"
Event = require "Event"
sync = require "sync"

SectionHeader = require "./SectionHeader"
ScrollChild = LazyVar -> require "./Child"

type = Type "Scrollable_Section"

type.defineOptions
  startIndex: Number.withDefault 0
  endIndex: Number.withDefault 0
  batchSize: Number.withDefault 1
  header: ScrollHeader.Kind
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

  _batchSize: options.batchSize

  # TODO: This can be used to keep the number of
  #       rendered children down to a reasonable amount.
  # renderLimit: fromArgs "renderLimit"

  _startIndex: options.startIndex

  _endIndex: options.endIndex

  _rendering: null

  _children: ReactiveList()

  _childElements: []

  _headerElements: []

  _footerElement: null

  _footerLength: null

  _section: null

  _scroll: null

type.defineReactiveValues ->

  _index: null

  _offset: null

  _length: null

  _firstVisibleIndex: null

  _lastVisibleIndex: null

type.defineGetters

  isEmpty: -> @_children.isEmpty

  isVisible: -> @_isVisible

  index: -> @_index

  offset: -> @_offset

  length: -> @_length

  firstVisibleIndex: -> @_firstVisibleIndex

  lastVisibleIndex: -> @_lastVisibleIndex

  section: -> @_section

  scroll: -> @_scroll

  _isRoot: -> this is @_scroll._section

type.definePrototype

  children:
    get: -> @_children.array
    set: (children) ->
      assertType children, Array

      {length} = children
      elements = new Array length
      if length
        section = this
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
      @_startIndex = clampValue newValue, 0, @_children.length

  endIndex:
    get: -> @_endIndex
    set: (newValue) ->
      @_endIndex = clampValue newValue, 0, @_children.length

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

  # TODO: Insert an undefined value at 'view._children[index]'
  insert: (index, child) ->

    assertType index, Number
    assert index >= 0 and index < @_children.length, { index, reason: "'index' out of bounds!" }

    { length } = children = @_children

    sync.repeat length - index, (offset) ->
      children[index + offset]._index += 1

    assertType child, ScrollChild.get()
    @_initChild child, index

    children.splice index, 0, child
    @_childElements.splice index, 0, no
    return

  remove: (index, count) ->

    assertType index, Number
    assertType count, Number

    return if count <= 0

    { length } = children = @_children

    startIndex = Math.min index + count, length
    sync.repeat length - startIndex, (offset) ->
      children[startIndex + offset]._index -= 1

    # TODO: Do the removed children need any properties nullified?
    children.splice index, count
    @_childElements.splice index, count
    return

  forceUpdate: ->
    @view and @view.forceUpdate()
    return

  # TODO: Support rendering children above the visible region.
  renderWhile: (shouldRender) ->
    return Promise() unless shouldRender()
    return @_rendering ?= Promise.defer (resolve) =>

      @endIndex += @batchSize
      # @startIndex -= @batchSize if (@endIndex - @startIndex) >= @renderLimit

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

  _setSection: (newValue) ->
    oldValue = @_section

    if newValue and oldValue
      throw Error "Must set section to null first!"

    if @_section = newValue
      @__onInsert()
    else if oldValue
      @__onRemove()
    return

  _initChild: (child, index) ->
    child._index = index
    child._section = this
    if child instanceof ScrollSection
      child._scroll = @_scroll
    return

  _prependChild: (child) ->

    assertType child, ScrollChild.get()

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
      assertType child, ScrollChild.get()
      section._initChild child, index
      elements[index] = no

    @_children.prepend children
    @_childElements = elements.concat @_childElements
    return

  _appendChild: (child) ->

    assertType child, ScrollChild.get()

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
      assertType child, ScrollChild.get()
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
    numChildren = @_children._length

    # TODO: Use an `estimatedRowSize` with `startOffset`
    #   to help find the `firstVisibleIndex` faster.
    beforeVisibleRange = yes
    lastVisibleIndex = null

    elements = @_childElements
    index = -1
    while ++index < numChildren
      child = children[index]

      if element is no
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
    else @_isVisible = scroll._isAreaVisible @_offset, @_length
    @didLayout.emit()

  _onFooterLayout: (layout) ->
    @_footerLength = layout[if @scroll.axis is "x" then "width" else "height"]

type.defineHooks

  __onInsert: emptyFunction

  __onRemove: emptyFunction

  # TODO: Support this hook.
  #       Allow a Promise to be returned for
  #       asynchronous updates before the section is removed.
  # __willRemove: emptyFunction

#
# Rendering
#

type.propTypes =
  style: Style
  removeClippedSubviews: Boolean

type.propDefaults =
  removeClippedSubviews: no # TODO: Should this be `yes`?

type.render ->
  return View
    style: @props.style
    children: @_renderSection()
    removeClippedSubviews: @props.removeClippedSubviews
    onLayout: (event) => @_onLayout event.nativeEvent.layout

type.defineMethods

  _renderSection: ->

    return @__renderEmpty() if @isEmpty

    { length } = children = @_renderChildren()

    @_headerElements[0] ?= if @_header then @_header.renderEmpty() else @__renderHeader()
    @_headerElements[1] ?= if @_header then @_header.render() else false

    if @_children.length is length
      @_footerElement ?= View
        children: @__renderFooter()
        onLayout: (event) =>
          @_onFooterLayout event.nativeEvent.layout

    return [
      @_headerElements[0]
      children
      @_headerElements[1]
      @_footerElement
    ]

  _renderChildren: ->

    { startIndex, endIndex } = this
    length = endIndex - startIndex

    children = @_children
    elements = @_childElements

    # TODO: Only iterate the unmounted children?
    offset = -1
    while ++offset < length
      index = startIndex + offset
      continue if elements[index] isnt no
      elements[index] = children[index].render()

    # TODO: Hide mounted children that are not in the active range?
    return elements

type.defineHooks

  __renderHeader: emptyFunction.thatReturnsFalse

  __renderFooter: emptyFunction.thatReturnsFalse

  __renderEmpty: emptyFunction.thatReturnsFalse

module.exports = ScrollSection = type.build()
