
{Type, Element} = require "modx"
{View} = require "modx/views"

emptyFunction = require "emptyFunction"
Event = require "Event"

ScrollChild = require "./Child"

type = Type "Scrollable_Row"

type.inherits ScrollChild

type.defineOptions
  key: String
  props: Object
  render: Function.Kind
  element: Element

type.defineValues (options) ->

  _key: options.key

  _props: options.props

  _render: options.render

  _element: options.element

type.defineValues

  __renderContents: ->
    if @_element then -> @_element
    else if @_render then -> @_render @_props

type.defineGetters

  scroll: -> @_section.scroll

  didLayout: -> @_didLayout.listenable

type.defineMethods

  _onLayout: (layout) ->
    {scroll} = this
    @_offset = layout[scroll.axis]
    @_length = layout[if scroll.axis is "x" then "width" else "height"]
    # @_isVisible = scroll._isAreaVisible @_offset, @_length
    #   TODO: Update visibility of nested rows.
    @_didLayout.emit()

#
# Rendering
#

type.render ->
  return View
    key: @_key
    style: @styles.container()
    children: @__renderContents()
    onLayout: (event) =>
      @_onLayout event.nativeEvent.layout

type.willMount ->
  @_props and @_props.row = this

type.willUnmount ->
  @_props and @_props.row = null

type.defineHooks

  __renderContents: emptyFunction.thatReturnsFalse

type.defineStyles

  container:
    overflow: "hidden"
    opacity: -> @opacity

module.exports = type.build()
