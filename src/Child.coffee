
emptyFunction = require "emptyFunction"
Event = require "Event"
Type = require "Type"

type = Type "Scrollable_Child"

type.defineValues

  _section: null

  _didLayout: -> Event()

type.defineReactiveValues

  _index: null

  _isVisible: null

type.defineProperties

  _offset:
    value: null
    reactive: yes
    didSet: (newOffset, oldOffset) ->
      return if newOffset is oldOffset
      log.it @__name + ".offset = " + newOffset
      @__onOffsetChange newOffset, oldOffset

  _length:
    value: 0
    reactive: yes
    didSet: (newLength, oldLength) ->
      return if newLength is oldLength
      log.it @__name + ".length = " + newLength
      @__onLengthChange newLength, oldLength

  _section:
    value: null
    didSet: (newSection, oldSection) ->
      return if newSection is oldSection
      oldSection and @__onRemove()
      newSection and @__onInsert()
      return

type.defineGetters

  isVisible: -> @_isVisible

  index: -> @_index

  offset: -> @_offset

  length: -> @_length

  section: -> @_section

  scroll: -> @_section.scroll

  didLayout: -> @_didLayout.listenable

type.defineHooks

  # By default, this implements cascading
  # '__onOffsetChange' calls to all mounted
  # children that come after this child.
  __onOffsetChange: (newOffset) ->
    return if @_length is null
    if childBelow = @_section.get @index + 1
      childBelow._offset = newOffset + @_length
    return

  __onLengthChange: emptyFunction

  __onInsert: emptyFunction

  __onRemove: emptyFunction

  # TODO: Allow a Promise to be returned for asynchronous updates before the child is removed.
  # __willRemove: emptyFunction

module.exports = type.build()
