
# TODO: Save memory by replacing offscreen children with empty views of the same length.

require "isDev"

{Type, Style} = require "modx"
{Number} = require "Nan"
{View} = require "modx/views"

emptyFunction = require "emptyFunction"
ReactiveList = require "ReactiveList"
assertType = require "assertType"
clampValue = require "clampValue"
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

type.defineReactiveValues

  _headerLength: null

  _footerLength: null

  _scroll: null

type.defineValues (options) ->

  # TODO: This can be used to keep the number of
  #       rendered children down to a reasonable amount.
  # renderLimit: options.renderLimit

  _batchSize: options.batchSize

  _children: ReactiveList()

  _childElements: []

  _headerElement: no

  _footerElement: no

  _visibleRange: []

  _mountedRange: options.mountedRange or [0, -1]

  _mountingBehind: null

  _mountingAhead: null

type.defineGetters

  array: -> @_children.array

  isEmpty: -> @_children.isEmpty

  startIndex: -> @_mountedRange[0]

  endIndex:  -> @_mountedRange[1]

  mountedRange: -> @_mountedRange.slice()

  visibleRange: -> @_visibleRange.slice()

  scroll: -> @_scroll

  _isRoot: -> this is @_scroll._children

type.defineMethods

  inspect: ->
    { @index, @offset, @length, children: @_children.length, @mountedRange, @visibleRange }

  get: (index) ->
    if Array.isArray index
      child = @_children.get index.shift()
      return child if index.length is 0
      return unless child instanceof ScrollSection
      return child.get index
    return @_children.get index

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

    # Perform child-specific clean-up.
    @_detachChild children[index]

    # Update the indexes of children below.
    childAbove = children[index - 1]
    sync.repeat @_children.length - index, (offset) ->
      child = children[index + offset]
      child._index -= 1
      if childAbove
        child._setOffset childAbove.offset + childAbove.length
      else child._setOffset 0
      childAbove = child

    # Remove from child storage.
    @_childElements.splice index, count
    @_children.remove index
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

  # NOTE: When 'amount' is negative, 'startIndex' is subtracted from.
  #       When 'amount' is positive, 'endIndex' is added to.
  mount: (arg) ->
    assertType arg, Array.or Function

    if Array.isArray arg
      return @_setMountedRange arg

    return Promise.try =>
      [startIndex, endIndex] = @_mountedRange
      context = {startIndex, endIndex}
      arg.call context
      {startIndex, endIndex} = context
      return @_setMountedRange [startIndex, endIndex]

  # NOTE: Pass a negative 'distance' to render behind.
  mountOffscreen: (distance) ->
    [startIndex, endIndex] = @_mountedRange

    if distance > 0
      if @_scroll.contentLength < (@_scroll.offset + @_scroll.visibleLength + distance)
        return @_setMountedRange [startIndex, endIndex + @_batchSize]

    else if @_scroll.offset < 0 - distance
      return @_setMountedRange [startIndex - @_batchSize, endIndex]

    return Promise()

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
    child._setSection this
    return

  _detachChild: (child) ->
    child._setSection null
    if child instanceof ScrollSection
      child._scroll = null
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

  _setMountedRange: (newRange) ->
    oldRange = @_mountedRange
    children = @_children.array
    maxIndex = @_children.length - 1

    startIndex = clampValue newRange[0], 0, maxIndex
    endIndex = clampValue newRange[1], 0, maxIndex
    if startIndex is oldRange[0]
      return Promise() if endIndex is oldRange[1]

    log.it @__name + ".mountedRange = [#{startIndex}, #{endIndex}]"
    @_mountedRange = [startIndex, endIndex]
    promises = []

    # Find new children that are being
    # rendered *above* the 'mountedRange'.
    if oldRange[0] - startIndex > 0
      index = oldRange[0]
      while --index >= startIndex
        promise = children[index]._mountWillBegin()
        promises.push promise

    # Find new children that are being
    # rendered *below* the 'mountedRange'.
    if endIndex - oldRange[1] > 0
      index = oldRange[1]
      while ++index <= endIndex
        promise = children[index]._mountWillBegin()
        promises.push promise

    # Update even if there are no children being mounted,
    # because some children might want to be unmounted.
    @view and @view.forceUpdate()
    if not promises.length
      return Promise()

    if @_mounting isnt null
      return Promise.all promises

    @_mountWillBegin()
    return Promise.all promises
      .then => @_mountDidFinish()

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

  _childDidLayout: (child, lengthChange) ->
    @_setLength @_length + lengthChange
    @_isRoot and @_scroll._childDidLayout child, lengthChange
    return

type.overrideMethods

  __lengthDidChange: (length, oldLength) ->

    if @_offset is null and length isnt null
      @_offset = 0 if @_isRoot or @isFirst

    @__super arguments

    if @_isRoot
      @_scroll._setContentLength length
    else
      @_section._childDidLayout this, length - oldLength

    @didLayout.emit()
    return

  __mountWillBegin: ->
    [startIndex, endIndex] = @_mountedRange
    return if startIndex > endIndex
    children = @_children.array
    index = startIndex - 1
    while ++index <= endIndex
      children[index]._mountWillBegin()
    return

  __mountWillFinish: ->
    [startIndex, endIndex] = @_mountedRange
    return if startIndex > endIndex
    promises = []
    children = @_children.array
    index = startIndex - 1
    while ++index <= endIndex
      promises.push children[index]._mounting
    return Promise.all promises

#
# Rendering
#

type.defineProps
  style: Style
  removeClippedSubviews: Boolean.withDefault no # TODO: Should this be `yes`?

type.render ->
  return View
    removeClippedSubviews: @props.removeClippedSubviews
    style: [
      @styles.container()
      @props.style
    ]
    children: [
      @_renderHeader()
      if @isEmpty then @__renderEmpty()
      else @_renderContents()
      @_renderFooter()
    ]

type.defineMethods

  _renderHeader: ->

    if @_headerElement isnt no
      return @_headerElement

    return @_headerElement = View
      children: @__renderHeader()
      onLayout: (event) =>
        {layout} = event.nativeEvent
        oldLength = @_headerLength
        @_headerLength = layout[if @_scroll.isHorizontal then "width" else "height"]
        @_setLength @_length + @_headerLength - oldLength

  _renderContents: ->
    [startIndex, endIndex] = @_mountedRange
    return [] if endIndex < 0

    children = @_children._array
    elements = @_childElements
    index = startIndex - 1
    while ++index <= endIndex
      continue if elements[index] isnt no
      elements[index] = children[index].render()

    return View
      style: @styles.contents()
      children: elements

  _renderFooter: ->

    if @_footerElement isnt no
      return @_footerElement

    return @_footerElement = View
      children: @__renderFooter()
      onLayout: (event) =>
        {layout} = event.nativeEvent
        oldLength = @_footerLength
        @_footerLength = layout[if @_scroll.isHorizontal then "width" else "height"]
        @_setLength @_length + @_footerLength - oldLength

type.defineHooks

  __renderHeader: emptyFunction.thatReturnsFalse

  __renderFooter: emptyFunction.thatReturnsFalse

  __renderEmpty: emptyFunction.thatReturnsFalse

type.defineStyles

  container: null

  contents: null

module.exports = ScrollSection = type.build()
