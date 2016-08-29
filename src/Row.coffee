
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

  _root: null

type.defineValues

  __renderContents: ->
    if @_element then -> @_element
    else if @_render then -> @_render @_props

type.defineBoundMethods

  _rootDidRef: (view) ->
    @_root = if view then view.child else null

  _rootDidLayout: (event) ->
    {layout} = event.nativeEvent

    newLength = layout[if @scroll.isHorizontal then "width" else "height"]
    return if newLength is oldLength = @_length

    @_setLength newLength
    @_section._childDidLayout this, newLength - oldLength

    # @_isVisible = @scroll._isAreaVisible @_offset, newLength
    @_didLayout.emit()
    return

type.defineMethods

  attachRoot: ->
    @_root.setNativeProps
      style: {position: "relative", opacity: 1}

  detachRoot: ->
    @_root.setNativeProps
      style: {position: "absolute", opacity: 0}

type.overrideMethods

  __lengthDidChange: (length) ->

    if length isnt null
      @isFirst and @_offset = 0

    @__super arguments

#
# Rendering
#

type.render ->
  return View
    key: @_key
    ref: @_rootDidRef
    style: @styles.container()
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
