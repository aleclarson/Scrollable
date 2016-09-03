
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

#
# Prototype-related
#

type.defineBoundMethods

  _rootDidLayout: (event) ->
    {layout} = event.nativeEvent

    newLength = layout[if @scroll.isHorizontal then "width" else "height"]
    return if newLength is oldLength = @_length

    @_setLength newLength
    @_section.__childDidLayout this, newLength - oldLength
    @_didLayout.emit()
    return

#
# Rendering
#

type.render ->
  return View
    key: @_key
    ref: @_rootDidRef
    style: [
      @styles.container()
      @_rootStyle
    ]
    children: @__renderContents()
    onLayout: @_rootDidLayout

type.willMount ->
  @props.row = this

type.willReceiveProps (props) ->
  props.row = this

type.defineHooks

  __renderContents: emptyFunction.thatReturnsFalse

type.defineStyles

  container:
    position: "absolute"
    overflow: "hidden"
    opacity: 0

module.exports = type.build()
