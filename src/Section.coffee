
# TODO: Save memory by replacing offscreen children with empty views of the same length.

require "isDev"

{Type, Style} = require "modx"
{View} = require "modx/views"

emptyFunction = require "emptyFunction"
ReactiveList = require "ReactiveList"
assertType = require "assertType"
Promise = require "Promise"
Random = require "random"
Event = require "Event"
Range = require "Range"
sync = require "sync"

SectionHeader = require "./SectionHeader"
ScrollChild = require "./Child"

type = Type "Scrollable_Section"

type.inherits ScrollChild

type.defineOptions
  mountedRange: Range
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

  _mountedRange: options.mountedRange or [0, -1]

  _visibleRange: []

  _children: ReactiveList()

  _childElements: []

  _headerElement: no

  _headerLength: null

  _footerElement: no

  _footerLength: null

  _scroll: null

type.defineGetters

  array: -> @_children.array

  isEmpty: -> @_children.isEmpty

  visibleRange: -> @_visibleRange.slice()

  scroll: -> @_scroll

  _isRoot: -> this is @_scroll._children

type.definePrototype

  startIndex:
    get: -> @_mountedRange[0]
    set: (index) ->
      @_children._assertValidIndex index
      @_mountedRange[0] = index

  endIndex:
    get: -> @_mountedRange[1]
    set: (index) ->
      @_children._assertValidIndex index
      @_mountedRange[1] = index

  mountedRange:
    get: -> @_mountedRange
    set: (range) ->
      assertType range, Range
      @_mountedRange = range
      @view and @_tryMounting()

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
    @_attachChild child, index

    @_childElements.splice index, 0, no
    @_children.insert index, child
    return

  remove: (index) ->

    assertType index, Number

    isDev and @_children._assertValidIndex index

    children = @_children._array
    sync.repeat @_children.length - index, (offset) ->
      children[index + offset]._index -= 1

    @_childElements.splice index, count
    @_detachChild @_children.remove index
    return

  replaceAll: (children) ->
    assertType children, Array
    section = this

    oldChildren = @_children._array
    oldChildren and oldChildren.forEach (child) ->
      section._detachChild child

    elements = new Array children.length
    children.forEach (child, index) ->
      section._attachChild child, index
      elements[index] = no

    @_visibleRange.length = 0
    @_isRoot and @_scroll._setContentLength null

    @_children.array = children
    @_childElements = elements
    return

  forceUpdate: (callback) ->
    @view and @view.forceUpdate callback
    return

  # NOTE: Pass a negative 'distance' to render behind.
  mountAhead: (distance) ->
    [startIndex, endIndex] = @_mountedRange

    if distance > 0
      if @_scroll.contentLength < (@_scroll.offset + @_scroll.visibleLength + distance)
        endIndex = Math.min endIndex + @_batchSize, @_children._length._value
        if endIndex isnt @_mountedRange[1]
          @_mountedRange = [startIndex, endIndex]
          return @_tryMounting()

    else if @_scroll.contentLength < (@_scroll.offset - distance)
      startIndex = Math.max startIndex - @_batchSize, 0
      if startIndex isnt @_mountedRange[0]
        @_mountedRange = [startIndex, endIndex]
        return @_tryMounting()

    return Promise no

  updateVisibleRange: ->
    startOffset = @_scroll.offset
    endOffset = startOffset + @_scroll.visibleLength
    if @_visibleRange.length
      @_updateVisibleRange startOffset, endOffset
    else @_initVisibleRange startOffset, endOffset
    return @_visibleRange

  _attachChild: (child, index) ->

    if child instanceof ScrollSection
      child._scroll = @_scroll

    child._index = index
    child._section = this
    return

  _detachChild: (child) ->

    if child instanceof ScrollSection
      child._scroll = null

    child._index = null
    child._section = null
    return

  _prependChild: (child) ->

    assertType child, ScrollChild.Kind

    # Increment the `index` of every child.
    @_children.forEach (child) ->
      child._index += 1

    @_attachChild child, 0

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
      section._attachChild child, index
      elements[index] = no

    @_children.prepend children
    @_childElements = elements.concat @_childElements
    return

  _appendChild: (child) ->

    assertType child, ScrollChild.Kind

    @_attachChild child, @_children.length

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
      section._attachChild child, index + offset
      elements[index] = no

    @_children.append children
    @_childElements = @_childElements.concat elements
    return

  _tryMounting: ->
    {promise, resolve} = Promise.defer()

    if isDev and not @view
      throw Error "Must be mounted before calling '_tryMounting'!"

    onLayout = @didLayout 1, resolve
    onLayout.start()

    @view.forceUpdate()
    return promise

  _isAreaVisible: (offset, length) ->
    return null if @_scroll.visibleLength is null
    startOffset = @offset
    endOffset = top + @_scroll.visibleLength
    return yes if offset < endOffset
    return offset + length > startOffset

  _getVisibleChildren: ->
    return null if not @_visibleRange.length
    return @_children.array.slice @_visibleRange[0], @_visibleRange[1] + 1

  # Computes the visible range from scratch.
  # TODO: Make this more performant?
  _initVisibleRange: (startOffset, endOffset) ->
    children = @_children._array
    numChildren = @_children.length

    # TODO: Use an `estimatedRowSize` with `startOffset`
    #   to help find `visibleRange[0]` faster.
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
        @_visibleRange[0] = index

    if beforeVisibleRange
      @_visibleRange.length = 0
      return

    @_visibleRange[1] = lastVisibleIndex
    return

  # Updates the visible range using its existing values.
  _updateVisibleRange: (startOffset, endOffset) ->

    if not @_visibleRange.length
      return @_initVisibleRange startOffset, endOffset

    children = @_children._array

    # Find children outside the visible range
    # that are >= the "first visible index".
    index = startIndex = @_visibleRange[0]
    while child = children[index]
      break if (child.offset + child.length) > startOffset
      @_visibleRange[0] = index
      index += 1

    # If the "first visible index" did not change...
    if @_visibleRange[0] is startIndex

      # Find children inside the visible range
      # that are < the "first visible index".
      index = startIndex - 1
      while child = children[index]
        break if (child.offset + child.length) < startOffset
        @_visibleRange[0] = index
        index -= 1

    # Find children outside the visible range
    # that are <= the "last visible index".
    index = startIndex = @_visibleRange[1]
    while child = children[index]
      break if child.offset < endOffset
      @_visibleRange[1] = index
      index -= 1

    # If the "last visible index" did not change...
    if @_visibleRange[1] is startIndex

      # Find children inside the visible range
      # that are > the "last visible index".
      index = startIndex + 1
      while child = children[index]
        break if child.offset > endOffset
        @_visibleRange[1] = index
        index += 1

    return

type.overrideMethods

  # This implements cascading 'didLayout' events
  # whenever the length of a child is changed.
  __onLengthChange: (newValue, oldValue) ->
    return if newValue is oldValue

    if @_isRoot
      @_scroll._setContentLength newValue
      return

    @_section._length += newValue - oldValue
    @didLayout.emit()
    return

#
# Rendering
#

type.defineProps
  style: Style
  removeClippedSubviews: Boolean.withDefault no # TODO: Should this be `yes`?

type.render ->

  section =
    if @isEmpty then @__renderEmpty()
    else @__renderSection()

  return View
    style: @props.style
    children: section
    removeClippedSubviews: @props.removeClippedSubviews

type.defineMethods

  _renderHeader: ->

    if @_headerElement isnt no
      return @_headerElement

    return @_headerElement = View
      children: @__renderHeader()
      onLayout: (event) =>
        {layout} = event.nativeEvent
        @_headerLength = layout[if @_scroll.isHorizontal then "width" else "height"]

  _renderChildren: ->
    [startIndex, endIndex] = @_mountedRange
    return [] if endIndex < 0
    children = @_children._array
    elements = @_childElements
    index = startIndex - 1
    while ++index <= endIndex
      continue if elements[index] isnt no
      elements[index] = children[index].render()
    return elements

  _renderFooter: ->

    if @_footerElement isnt no
      return @_footerElement

    return @_footerElement = View
      children: @__renderFooter()
      onLayout: (event) =>
        {layout} = event.nativeEvent
        @_footerLength = layout[if @_scroll.isHorizontal then "width" else "height"]

type.defineHooks

  __renderHeader: emptyFunction.thatReturnsFalse

  __renderFooter: emptyFunction.thatReturnsFalse

  __renderEmpty: emptyFunction.thatReturnsFalse

  __renderSection: -> [
    @_renderHeader()
    @_renderChildren()
    @_renderFooter()
  ]

module.exports = ScrollSection = type.build()
