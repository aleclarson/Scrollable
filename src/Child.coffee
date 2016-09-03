
{Type} = require "modx"

emptyFunction = require "emptyFunction"
Promise = require "Promise"
Event = require "Event"

revealedStyle = {position: "relative", opacity: 1}
concealedStyle = {position: "absolute", opacity: 0}

type = Type "Scrollable_Child"

type.defineValues

  _root: null

  _rootStyle: revealedStyle

  _mounting: null

  _mountDeps: null

  _didLayout: -> Event()

type.defineReactiveValues

  _section: null

  _index: null

  _offset: null

  _length: null

  _isRevealed: no

  _isConcealed: no

  _inVisibleArea: null

type.willMount ->
  @_mountDeps = @__getMountDeps()

type.didMount ->
  @_mounting and @_mounting.resolve()

#
# Prototype-related
#

type.defineGetters

  index: -> @_index

  startOffset: -> @_offset

  endOffset: -> @_offset + @_length

  length: -> @_length

  isMounted: -> @_mounting and @_mounting.promise.isFulfilled

  isRevealed: -> @_isRevealed

  isConcealed: -> @_isConcealed

  isConcealedByParent: -> @_section and not @_section.isRevealed

  inVisibleArea: -> @_inVisibleArea

  isFirst: -> @index is @_section.startIndex

  isLast: -> @index is @_section.endIndex

  section: -> @_section

  scroll: -> @_section.scroll

  didLayout: -> @_didLayout.listenable

type.defineBoundMethods

  _rootDidRef: (view) ->
    @_root = view
    return

type.defineMethods

  reveal: ->
    return if not @_isConcealed
    @_isConcealed = no
    @_rootStyle = revealedStyle
    if @_root and @isMounted
      @isConcealedByParent or @_reveal()
    return

  conceal: ->
    return if @_isConcealed
    @_isConcealed = yes
    @_rootStyle = concealedStyle
    if @_root and @isMounted
      @_root.setNativeProps {style: concealedStyle}
      @__onConceal()
    return

  _reveal: ->

    if isDev
      if @_isRevealed
        return console.warn "Already revealed!"
      if @_offset isnt null
        return console.warn "'_offset' cannot be set before '__onReveal'!"

    @_isRevealed = yes
    @_root.setNativeProps {style: revealedStyle}
    @__onReveal()
    return

  _setSection: (section) ->
    if section isnt oldSection = @_section
      @__sectionWillRemove() if oldSection
      return if not section
      @_section = section
      @__sectionDidInsert()
    return

  _setOffset: (offset) ->
    if offset isnt oldOffset = @_offset
      log.it @__name + ".offset = " + offset
      @_offset = offset
      @__offsetDidChange offset, oldOffset
    return

  _setLength: (length) ->
    if length isnt oldLength = @_length
      @_length = length
      @__lengthDidChange length, oldLength
    return

  _trackMounting: ->

    if @_mounting
      return @_mounting.promise

    {resolve, promise} = Promise.defer()

    promise = promise
      .then => @_mountDeps
      .then => @__onMountFinish()

    @_mounting = {resolve, promise}
    return promise

  _onLayout: (offset, length) ->

    if @_isRevealed and
       @_section isnt null and
       offset isnt null and
       length isnt null

      childBelow = @_section.get @index + 1
      if childBelow and childBelow.isRevealed
        childBelow._setOffset offset + length
      return

type.defineHooks

  __getMountDeps: emptyFunction

  __onMountFinish: ->
    log.it @__name + ".isMounted = true"
    @_reveal() unless @_isConcealed or @isConcealedByParent
    return

  __onReveal: ->

    if @_section
      childAbove = @_section.get @_index - 1

      if childAbove
        return if childAbove.length is null
        if childAbove.isRevealed
          @_setOffset childAbove.endOffset
          return

    @_setOffset 0
    return

  __onConceal: ->
    @_isRevealed = no
    @_inVisibleArea = null
    @_setOffset null
    return

  __offsetDidChange: (offset) ->
    @_onLayout offset, @_length
    return

  __lengthDidChange: (length) ->
    @_onLayout @_offset, length
    return

  __sectionDidInsert: emptyFunction

  # TODO: Support returning a Promise.
  __sectionWillRemove: ->
    @_index = null
    @_mounting = null
    @_mountDeps = null
    @_inVisibleArea = null
    @_setOffset null
    @_setLength null
    return

module.exports = type.build()
