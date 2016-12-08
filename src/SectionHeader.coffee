
emptyFunction = require "emptyFunction"
ReactType = require "modx/lib/Type"
View = require "modx/lib/View"

type = ReactType "Scrollable_SectionHeader"

type.defineOptions
  sticky: Boolean.withDefault no
  length: Number.withDefault 0

type.defineValues (options) ->

  _minTop: null

  _section: null

  _sticky: options.sticky

type.defineGetters

  section: -> @_section

  scroll: -> @_section.scroll

type.definePrototype

  offset:
    get: -> @_offset.value
    set: (newValue) ->
      @_offset.value = newValue

  length:
    get: -> @_length.value
    set: (newLength) ->
      @_length.value = newLength

type.defineMethods

  _onLayout: (layout) ->

    { scroll } = this

    @_minTop = layout[scroll.axis]

    length = layout[if scroll.axis is "x" then "width" else "height"]

    if @_length.value > 0
      if @_length.value isnt length
        throw Error "Predicted length does not match real length!"
      return

    @_length.value = length
    return

#
# Rendering
#

type.defineAnimatedValues (options) ->

  _offset: 0

  _length: options.length

type.defineStyles

  header:
    position: "absolute"
    left: 0
    right: 0
    translateX: -> @_offset if @scroll.axis is "x"
    translateY: -> @_offset if @scroll.axis is "y"
    flexDirection: -> "row" if @scroll.axis is "y"

  emptyHeader:
    alignSelf: "stretch"
    width: -> @_length if @scroll.axis is "x"
    height: -> @_length if @scroll.axis is "y"

type.render ->
  return View
    style: @styles.header()
    children: @__renderContent()
    onLayout: (event) => @_onLayout event.nativeEvent.layout

type.shouldUpdate ->
  return no

type.defineMethods

  renderEmpty: ->
    return View
      style: @styles.emptyHeader()

type.defineHooks

  __renderContent: emptyFunction.thatReturnsFalse

module.exports = ScrollHeader = type.build()

# type.defineNativeValues
#
#   return {} unless @section._stickyHeader
#
#   stickyHeaderDisplay: "absolute"
#
#   stickyHeaderHeight: NativeValue()
#
#   stickyHeaderTop: 0

  # _createScrollListener: ->
  #   @_scrollListener = @scroll.didScroll (offset) =>
  #     # if offset > @y
  #     # @view.stickyHeaderTop.value =


  # renderStickyHeader: (header) ->
  #
  #   position = @stickyHeaderDisplay
  #   transform = [
  #     { translateY: @stickyHeaderTop }
  #   ]
  #
  #   onLayout = (x, y, width, height) =>
  #     # @stickyHeaderHeight.value = height
  #     # @stickyHeaderDisplay.value = "absolute"
  #
  #   stickyHeader = View {
  #     style: { position, transform }
  #     onLayout
  #     children: header
  #   }
  #
  #   return View
  #     children: stickyHeader
  #     style:
  #       position: "relative"
  #       height: @stickyHeaderHeight
