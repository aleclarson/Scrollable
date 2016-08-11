
{Type, Element} = require "modx"
{View} = require "modx/views"

emptyFunction = require "emptyFunction"
assert = require "assert"
Event = require "Event"

type = Type "Scrollable_Row"

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

  _didLayout: Event()

type.defineValues

  __renderContents: ->
    if @_element then -> @_element
    else if @_render then -> @_render @_props

type.defineReactiveValues

  _index: null

  _offset: null

  _length: 0

  _isVisible: null

type.defineProperties

  _section:
    value: null
    reactive: yes
    didSet: (newValue, oldValue) ->
      if newValue
        assert oldValue is null, "'this._section' must be null before setting to a non-null value!"
        @__onInsert()
      else if oldValue
        @__onRemove()

type.defineGetters

  index: -> @_index

  offset: -> @_offset

  length: -> @_length

  isVisible: -> @_isVisible

  section: -> @_section

  scroll: -> @_section.scroll

  didLayout: -> @_didLayout.listenable

type.defineMethods

  _onLayout: (layout) ->
    {scroll} = this
    @_offset = layout[scroll.axis]
    @_length = layout[if scroll.axis is "x" then "width" else "height"]
    @_isVisible = scroll._isAreaVisible @_offset, @_length
    @_didLayout.emit()

type.defineHooks

  __onInsert: emptyFunction

  __onRemove: emptyFunction

#
# Rendering
#

type.shouldUpdate ->
  return no

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
