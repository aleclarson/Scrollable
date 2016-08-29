
require "isDev"

{Type} = require "modx"

emptyFunction = require "emptyFunction"
Promise = require "Promise"
Event = require "Event"

type = Type "Scrollable_Child"

type.defineValues ->

  _mounting: null

  _didLayout: Event()

type.defineReactiveValues

  _index: null

  _offset: null

  _length: null

  _isVisible: null

  _section: null

type.defineGetters

  index: -> @_index

  offset: -> @_offset

  length: -> @_length

  isVisible: -> @_isVisible

  isMounting: -> @_mounting isnt null

  isFirst: -> @index is @_section.startIndex

  isLast: -> @index is @_section.endIndex

  section: -> @_section

  scroll: -> @_section.scroll

  didLayout: -> @_didLayout.listenable

type.defineMethods

  _setSection: (section) ->
    if section isnt oldSection = @_section
      @__sectionWillRemove() if oldSection
      return if not section
      @_section = section
      @__sectionDidInsert()
    return

  _setOffset: (offset) ->
    if offset isnt oldOffset = @_offset
      @_offset = offset
      @__offsetDidChange offset, oldOffset
    return

  _setLength: (length) ->
    if length isnt oldLength = @_length
      @_length = length
      @__lengthDidChange length, oldLength
    return

  _mountWillBegin: ->
    log.it @__name + "._mountWillBegin()"
    @_mounting = Promise.defer()
    @__mountWillBegin()
    return @_mounting.promise

  _mountDidFinish: ->
    log.it @__name + "._mountDidFinish()"
    @_mounting.resolve()
    @_mounting = null
    return

  # If both 'offset' and 'length' are non-null,
  # the offset of the child below is updated.
  _onLayout: (offset, length) ->
    return if @_section is null
    return if offset is null
    return if length is null
    if childBelow = @_section.get @index + 1
      childBelow._setOffset offset + length
    return

type.defineHooks

  __indexDidChange: emptyFunction

  __offsetDidChange: (offset) ->
    @_onLayout offset, @_length
    return

  __lengthDidChange: (length) ->
    @_onLayout @_offset, length
    return

  __mountWillBegin: emptyFunction

  __mountWillFinish: emptyFunction

  __sectionDidInsert: emptyFunction

  # TODO: Support returning a Promise.
  __sectionWillRemove: ->
    @_index = null
    @_setOffset null
    @_setLength null
    @_isVisible = null
    @_mounting = null
    return

type.didMount ->
  if isDev and not @_mounting
    throw Error "'_mounting' must exist before the 'didMount' phase!"

  mounting = @__mountWillFinish()
  if Promise.isPending mounting
    mounting.then => @_mountDidFinish()
    return

  @_mountDidFinish()
  return

module.exports = type.build()
