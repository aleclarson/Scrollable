
{View} = require "modx/views"
{Type} = require "modx"

emptyFunction = require "emptyFunction"
assert = require "assert"

type = Type "Scrollable_SectionHeader"

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

  top:
    get: -> @_top.value
    set: (newValue) ->
      @_top.value = newValue

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
      assert @_length.value is length, "Predicted length does not match real length!"
      return

    @_length.value = length
    return

#
# Rendering
#

type.defineNativeValues

  _top: 0

  _length: (options) -> options.length

type.defineStyles

  header:
    flexDirection: -> "row" if @scroll.axis is "y"
    position: "absolute"
    top: -> @_top
    left: 0
    right: 0

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
  #     log.it "#{@__id}.offset = " + offset
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
