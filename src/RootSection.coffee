
{Type} = require "modx"

emptyFunction = require "emptyFunction"

Section = require "./Section"

type = Type "Scrollable_RootSection"

type.inherits Section

type.defineOptions
  scroll: Object.Kind

type.defineValues (options) ->

  _scroll: options.scroll

type.initInstance ->
  @_index = 0
  @_trackMounting()

type.overrideMethods

  __lengthDidChange: (length) ->
    @_scroll._setContentLength length
    @__super arguments
    return

  __getVisibleArea: ->
    scroll = @_scroll
    return {
      startOffset: scroll.offset
      endOffset: scroll.offset + scroll.visibleLength
    }

  __onRemoveAll: ->
    @_scroll._setContentLength null
    return

  __renderEmpty: ->
    return @_scroll.__renderEmpty()

  __renderHeader: ->
    return @_scroll.__renderHeader()

  __renderFooter: ->
    return @_scroll.__renderFooter()

  __renderOverlay: ->
    return @_scroll.__renderOverlay()

  __childWillAttach: (child, index) ->
    return @_scroll.__childWillAttach child, index

  __childDidAttach: (child) ->
    @_scroll.__childDidAttach child
    return

  __childWillDetach: (child) ->
    @_scroll.__childWillDetach child
    return

  __childDidLayout: (child, lengthChange) ->
    @_setLength @_length + lengthChange
    @_scroll.__childDidLayout child, lengthChange
    return

module.exports = type.build()
