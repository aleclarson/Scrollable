
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

type.defineMethods

  _onLayout: (layout) ->
    newLength = layout[if @scroll.isHorizontal then "width" else "height"]
    return if newLength is oldLength = @_length
    @_length = newLength # NOTE: If a new '_length' exists, it must always be set before '_offset'!

    # NOTE: Since '_offset' is relative to '_section.offset',
    #       we can assume zero for the first row.
    if @index is 0
      @_offset = 0

    else if @_offset isnt null
      if childBelow = @_section.get @index + 1
        childBelow._offset = @_offset + newLength

    # NOTE: Since setting '_section._length' triggers cascading
    #       'didLayout' events, we must set it *after* updating
    #       the '_offset' and '_length' of this row.
    @_section._length += newLength - oldLength

    # TODO: Update row visibility?
    # @_isVisible = scroll._isAreaVisible @_offset, newLength

    @_didLayout.emit()
    return

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

type.willUpdate ->
  log.it @__name + ".willUpdate()"

type.willMount ->
  @props.row = this

type.willReceiveProps (props) ->
  props.row = this

type.defineHooks

  __renderContents: emptyFunction.thatReturnsFalse

type.defineStyles

  container:
    overflow: "hidden"

module.exports = type.build()
