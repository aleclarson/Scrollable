
emptyFunction = require "emptyFunction"
Event = require "Event"
Type = require "Type"

type = Type "Scrollable_Child"

type.defineValues

  _section: null

  _didLayout: -> Event()

type.defineReactiveValues

  _index: null

  _offset: null

  _length: null

  _isVisible: null

type.defineGetters

  isVisible: -> @_isVisible

  index: -> @_index

  offset: -> @_offset

  length: -> @_length

  section: -> @_section

  didLayout: -> @_didLayout.listenable

type.defineMethods

  _setSection: (newValue) ->
    oldValue = @_section

    if newValue and oldValue
      throw Error "Must set section to null first!"

    if @_section = newValue
      @__onInsert()
    else if oldValue
      @__onRemove()
    return

type.defineHooks

  __onInsert: emptyFunction

  __onRemove: emptyFunction

  # TODO: Allow a Promise to be returned for asynchronous updates before the section is removed.
  # __willRemove: emptyFunction

module.exports = type.build()
