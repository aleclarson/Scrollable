
# TODO: Save memory by replacing offscreen children with empty views of the same length.

{Type, Style} = require "modx"
{Number} = require "Nan"
{View} = require "modx/views"

emptyFunction = require "emptyFunction"
ReactiveRange = require "ReactiveRange"
ReactiveList = require "ReactiveList"
assertType = require "assertType"
Promise = require "Promise"
Event = require "Event"
Range = require "Range"
isDev = require "isDev"
sync = require "sync"

SectionHeader = require "./SectionHeader"
ScrollChild = require "./Child"

type = Type "Scrollable_Section"

type.inherits ScrollChild

type.defineOptions
  key: String
  mountedRange: Range
  batchSize: Number.withDefault 1
  header: SectionHeader.Kind
  renderHeader: Function
  renderFooter: Function
  renderEmpty: Function

type.defineStatics

  Header: get: -> SectionHeader

type.defineFrozenValues (options) ->

  didLayout: Event()

  _key: options.key

  _header: options.header

  __renderHeader: options.renderHeader

  __renderFooter: options.renderFooter

  __renderEmpty: options.renderEmpty

type.defineReactiveValues

  _headerLength: null

  _footerLength: null

  _scroll: null

type.defineValues (options) ->

  _batchSize: options.batchSize

  _children: ReactiveList()

  _elements:
    header: no
    children: []
    footer: no
    overlay: no

  _visibleRange: []

  _mountedRange: ReactiveRange options.mountedRange or [0, -1]

  _mountingRange: null

type.defineListeners ->

  @_mountedRange.didSet (newRange, oldRange) =>

    if isDev
      if newRange[0] < 0 or newRange[0] > @_children.length - 1
        throw Error "Index out of range: " + newRange[0]
      if newRange[1] < 0 or newRange[1] > @_children.length - 1
        throw Error "Index out of range: " + newRange[1]

    @_mountingRange = @_trackMountingRange newRange, oldRange
    return

#
# Prototype-related
#

type.defineGetters

  array: -> @_children.array

  isEmpty: -> @_children.isEmpty

  visibleRange: -> @_visibleRange

  scroll: -> @_scroll

type.definePrototype

  mountedRange:
    get: -> @_mountedRange.get()
    set: (range) ->
      @_mountedRange.set range

type.defineBoundMethods

  _headerDidLayout: (event) ->
    {layout} = event.nativeEvent
    length = layout[if @_scroll.isHorizontal then "width" else "height"]
    if length isnt oldLength = @_headerLength
      @_headerLength = length
      @_setLength @_length + length - oldLength
    return

  _footerDidLayout: (event) ->
    {layout} = event.nativeEvent
    length = layout[if @_scroll.isHorizontal then "width" else "height"]
    if length isnt oldLength = @_footerLength
      @_footerLength = length
      @_setLength @_length + length - oldLength
    return

type.defineMethods

  inspect: ->
    { @index, @startOffset, @endOffset, @length, children: @_children.length, @mountedRange, @visibleRange }

  get: (index) ->
    if Array.isArray index
      child = @_children.get index.shift()
      return child if index.length is 0
      return unless child instanceof ScrollSection
      return child.get index
    return @_children.get index

  prepend: (child) ->

    # Increment the `index` of every child.
    @_children.forEach (child) ->
      child._index += 1

    child = @_attachChild child, 0
    assertType child, ScrollChild.Kind

    @_children.prepend child
    @_elements.children.unshift no
    return

  append: (child) ->

    child = @_attachChild child, @_children.length
    assertType child, ScrollChild.Kind

    @_children.append child
    @_elements.children.push no
    log.it @__name + "._children.length = " + @_children.length
    return

  # TODO: Support inserting arrays of children.
  insert: (index, child) ->
    assertType index, Number

    isDev and @_children._assertValidIndex index

    children = @_children._array
    sync.repeat numChildren - index, (offset) ->
      children[index + offset]._index += 1

    child = @_attachChild child, index
    assertType child, ScrollChild.Kind

    @_elements.children.splice index, 0, no
    @_children.insert index, child
    return

  remove: (index) ->
    assertType index, Number
    isDev and @_children._assertValidIndex index

    children = @_children._array
    @_detachChild children[index]

    childAbove = children[index - 1]
    sync.repeat @_children.length - index, (offset) ->
      child = children[index + offset]
      child._index -= 1
      log.it @__name + ".index = " + child._index

      if child.isRevealed and
         childAbove and
         childAbove.length isnt null

        if childAbove.isRevealed
          child._setOffset childAbove.startOffset + childAbove.length
        else child._setOffset 0

      childAbove = child

    @_elements.children.splice index, count
    @_children.remove index
    return

  removeAll: ->
    return if @_children.length is 0
    @_children.forEach (child) =>
      @_detachChild child

    @_mountedRange.set [0, -1]
    @_visibleRange.length = 0

    @_children.length = 0
    @_elements.children.length = 0
    return

  mount: (range) ->
    assertType range, Array.or Function
    if Array.isArray range
      @_mountedRange.set range
    else range @_mountedRange
    return @_mountingRange

  # Pass a negative 'distance' to mount
  # any children before the 'mountedRange'.
  mountOffscreen: (distance) ->
    [startIndex, endIndex] = @_mountedRange.get()

    if distance > 0
      if @_scroll.contentLength < @_scroll.offset + @_scroll.visibleLength + distance
        @_mountedRange.set [startIndex, endIndex + @_batchSize]
        return @_mountingRange

    else if @_scroll.offset < 0 - distance
      @_mountedRange.set [startIndex - @_batchSize, endIndex]
      return @_mountingRange

    return Promise()

  forceUpdate: (callback) ->
    @view and @view.forceUpdate callback
    return

  # Called when a Row/Section is added to the 'children'.
  _attachChild: (child, index) ->
    child = @__childWillAttach child, index

    if child instanceof ScrollSection
      child._scroll = @_scroll

    child._index = index
    child._setSection this

    @__childDidAttach child
    return child

  # Called when a Row/Section is removed from the 'children'.
  _detachChild: (child) ->
    @__childWillDetach child

    child._setSection null

    if child instanceof ScrollSection
      child._scroll = null
    return

  _trackMountingRange: (newRange, oldRange) ->

    # Wait for all children (in the range) to finish mounting.
    children = @_children.array
    promises = []

    # Find new children that are being
    # rendered *above* the 'mountedRange'.
    if oldRange[0] - newRange[0] > 0
      index = oldRange[0]
      while --index >= newRange[0]
        child = children[index]
        @__childWillMount child
        promises.push child._trackMounting()

    # Find new children that are being
    # rendered *below* the 'mountedRange'.
    if newRange[1] - oldRange[1] > 0
      index = oldRange[1]
      while ++index <= newRange[1]
        child = children[index]
        @__childWillMount child
        promises.push child._trackMounting()

    # Update even if there are no children being mounted,
    # because some children might need to be unmounted.
    @view and @view.forceUpdate()

    if promises.length
      return Promise.all promises
    return Promise()

  _revealMountedRange: ->
    [startIndex, endIndex] = @_mountedRange.get()
    children = @_children.array
    index = startIndex - 1
    while ++index <= endIndex
      child = children[index]
      child._reveal() unless (
        child.isConcealed or
        child.isRevealed or
        not child.isMounted
      )

    return

  #
  # Visibility-related
  #

  _getVisibleChildren: ->
    return null if not @_visibleRange.length
    return @_children.array.slice @_visibleRange[0], @_visibleRange[1] + 1

  _isChildVisible: (index) ->
    return null if not @_visibleRange.length
    return no if index < @_visibleRange[0]
    return index <= @_visibleRange[1]

  _updateVisibility: ->
    if visibleArea = @__getVisibleArea()
      @_inVisibleArea = yes
      if @_visibleRange.length
        @_updateVisibleRange visibleArea.startOffset, visibleArea.endOffset
      else
        @_initVisibleRange visibleArea.startOffset, visibleArea.endOffset
      return

    @_inVisibleArea = no
    @_visibleRange = [-1, -1]
    return

  # Computes the visible range from scratch.
  # TODO: Make this more performant?
  _initVisibleRange: (startOffset, endOffset) ->
    children = @_children._array
    numChildren = @_children.length

    # TODO: Use an `estimatedRowSize` with `startOffset`
    #   to help find `visibleRange[0]` faster.
    beforeVisibleRange = yes
    lastVisibleIndex = null

    elements = @_elements.children
    index = -1
    while ++index < numChildren
      child = children[index]

      if elements[index] is no
        child._inVisibleArea = no
        continue if beforeVisibleRange
        break

      isHidden =
        if beforeVisibleRange
          (child.startOffset + child.length) < startOffset
        else child.startOffset > endOffset

      if isHidden
        child._inVisibleArea = no
        continue if beforeVisibleRange
        break

      child._inVisibleArea = yes
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
      @_initVisibleRange startOffset, endOffset
      return

    children = @_children._array

    # Find children outside the visible range
    # that are >= the "first visible index".
    index = startIndex = @_visibleRange[0]
    while child = children[index]
      break if (child.startOffset + child.length) > startOffset
      @_visibleRange[0] = index
      index += 1

    # If the "first visible index" did not change...
    if @_visibleRange[0] is startIndex

      # Find children inside the visible range
      # that are < the "first visible index".
      index = startIndex - 1
      while child = children[index]
        break if (child.startOffset + child.length) < startOffset
        @_visibleRange[0] = index
        index -= 1

    # Find children outside the visible range
    # that are <= the "last visible index".
    index = startIndex = @_visibleRange[1]
    while child = children[index]
      break if child.startOffset < endOffset
      @_visibleRange[1] = index
      index -= 1

    # If the "last visible index" did not change...
    if @_visibleRange[1] is startIndex

      # Find children inside the visible range
      # that are > the "last visible index".
      index = startIndex + 1
      while child = children[index]
        break if child.startOffset > endOffset
        @_visibleRange[1] = index
        index += 1

    log.it @__name + ".visibleRange = [ " + @_visibleRange.join(", ") + " ]"
    return

type.overrideMethods

  __didReveal: ->

    if @_section
      @_section.__childDidLayout this, @_length

    @_updateVisibility()
    @_revealMountedRange()
    return

  __offsetDidChange: (offset) ->
    log.it @__name + ".offset = " + offset
    @__super arguments

  __lengthDidChange: (length, oldLength) ->

    @__super arguments

    if @_isRevealed and @_section
      @_section.__childDidLayout this, length - oldLength

    @didLayout.emit()
    return

  __willMount: ->
    [startIndex, endIndex] = @_mountedRange.get()
    return if startIndex > endIndex

    children = @_children.array
    promises = []

    index = startIndex - 1
    while ++index <= endIndex
      promises.push children[index]._trackMounting()

    return Promise.all promises

type.defineHooks

  __getVisibleArea: ->
    @_scroll._isChildVisible this

  __onRemoveAll: emptyFunction

  __childWillAttach: emptyFunction.thatReturnsArgument

  __childDidAttach: emptyFunction

  __childWillDetach: emptyFunction

  __childWillMount: emptyFunction

  __childDidLayout: (child, lengthChange) ->
    @_setLength @_length + lengthChange
    return

  __childDidReveal: emptyFunction

  __childDidConceal: emptyFunction

#
# Rendering
#

type.defineProps
  style: Style

type.render ->
  return View
    key: @_key
    ref: @_rootDidRef
    style: [
      @styles.container()
      @props.style
      @_rootStyle
    ]
    children: [
      @_renderHeader()
      if @isEmpty then @__renderEmpty()
      else @_renderContents()
      @_renderFooter()
      @__renderOverlay()
    ]

type.defineMethods

  _renderHeader: ->

    if @_elements.header isnt no
      return @_elements.header

    return @_elements.header = View
      children: @__renderHeader()
      onLayout: @_headerDidLayout

  _renderContents: ->
    [startIndex, endIndex] = @_mountedRange.get()
    return [] if endIndex < 0

    children = @_children._array
    elements = @_elements.children
    index = startIndex - 1
    while ++index <= endIndex
      continue if elements[index] isnt no
      elements[index] = children[index].render()

    return View
      style: @styles.contents()
      children: elements

  _renderFooter: ->

    if @_elements.footer isnt no
      return @_elements.footer

    return @_elements.footer = View
      children: @__renderFooter()
      onLayout: @_footerDidLayout

type.defineHooks

  __renderEmpty: emptyFunction.thatReturnsFalse

  __renderHeader: emptyFunction.thatReturnsFalse

  __renderFooter: emptyFunction.thatReturnsFalse

  __renderOverlay: emptyFunction.thatReturnsFalse

type.defineStyles

  container: null

  contents: null

module.exports = ScrollSection = type.build()
