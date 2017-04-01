
emptyFunction = require "emptyFunction"
Promise = require "Promise"
Event = require "eve"
isDev = require "isDev"
modx = require "modx"

revealedStyle = {position: "relative", opacity: 1}
concealedStyle = {position: "absolute", opacity: 0}

type = modx.Type "Scrollable_Child"

type.defineValues

  _root: null

  # Although '_isConcealed' defaults to false, we don't want
  # to show this child until '_reveal' is called.
  _rootStyle: concealedStyle

  _mounting: null

  _mountDeps: null

  _didLayout: -> Event()

type.defineReactiveValues

  _section: null

  _index: null

  _length: null

  _offset: null

  _isRevealed: no

  _isConcealed: no

  _inVisibleArea: null

type.willMount ->
  @_mountDeps = @__willMount()

type.didMount ->
  @_mounting and @_mounting.resolve()

#
# Prototype-related
#

type.defineGetters

  index: -> @_index

  length: -> @_length

  startOffset: -> @_offset

  endOffset: -> @_offset + @_length

  isMounted: ->
    if @_mounting
    then @_mounting.promise.isFulfilled
    else no

  isRevealed: -> @_isRevealed

  isConcealed: -> @_isConcealed

  isConcealedByParent: ->
    if @_section
    then @_section.isRevealed is no
    else no

  inVisibleArea: -> @_inVisibleArea

  isFirst: -> @index is @_section.startIndex

  isLast: -> @index is @_section.endIndex

  section: -> @_section

  scroll: -> @_section.scroll

  didLayout: -> @_didLayout.listenable

type.defineBoundMethods

  _rootDidRef: (view) ->
    @_root = view
    @__didMount() if @isMounted
    return

type.defineMethods

  reveal: ->
    return unless @_isConcealed
    @_isConcealed = no
    @_rootStyle = revealedStyle
    @_tryReveal() if @_root and @isMounted
    return

  conceal: ->
    return if @_isConcealed
    @_isConcealed = yes
    @_rootStyle = concealedStyle
    if @_root and @isMounted
      @_root.setNativeProps {style: concealedStyle}
      @_conceal()
    return

  _tryReveal: ->
    return if @_isRevealed or @_isConcealed
    return if @isConcealedByParent
    return @_reveal()

  _reveal: ->

    if isDev
      if @_isRevealed
        return console.warn "Already revealed!"
      if @_offset isnt null
        return console.warn "'_offset' cannot be set before '__didReveal'!"

    @_isRevealed = yes
    @_rootStyle = revealedStyle
    @_root.setNativeProps {style: revealedStyle}
    @_setOffsetFromAbove()
    @__didReveal()
    if @_section
      @_section.__childDidReveal this
    return

  _conceal: ->

    if isDev and not @_isRevealed
      throw Error "Already concealed!"

    @_isRevealed = no
    @_inVisibleArea = null
    @_setOffset null
    @__didConceal()
    if @_section
      @_section.__childDidConceal this
    return

  _setSection: (section) ->
    if section isnt oldSection = @_section
      @__sectionWillRemove() if oldSection
      return unless section
      @_section = section
      @__sectionDidInsert()
    return

  _setLength: (length) ->
    if length isnt oldLength = @_length
      @_length = length
      @__lengthDidChange length, oldLength
    return

  _setOffset: (offset) ->
    if offset isnt oldOffset = @_offset
      @_offset = offset
      @__offsetDidChange offset, oldOffset
    return

  _setOffsetFromAbove: ->

    childAbove = @_section and @_section.get @_index - 1
    if childAbove and childAbove.isMounted
      return if childAbove.length is null
      if childAbove.isRevealed
        @_setOffset childAbove.endOffset
        return

    @_setOffset 0
    return

  _trackMounting: ->

    if @_mounting
      return @_mounting.promise

    {resolve, promise} = Promise.defer()

    promise = promise
      .then => @_mountDeps
      .then =>
        @__didMount() if @_root
        return

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

  __willMount: emptyFunction

  __didMount: ->
    @_tryReveal()
    return

  __didReveal: emptyFunction

  __didConceal: emptyFunction

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
