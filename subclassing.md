
# Subclassing

```coffee
{Component} = require "modx"

VirtualScroll = require "VirtualScroll"

type = Component.Type "MyScroll"

type.inherits VirtualScroll
```

### Properties

```coffee
# A computed value that depends on
# '_drag.offset' and '_edge.distance'.
_offset: NativeValue

# The drag responder!
_drag: Draggable

# Simulates boundary resistance.
_edge: Rubberband

# The 'offset' of the boundary being stretched.
# Equals either 'minOffset', 'maxOffset', or null.
_edgeOffset: Number

# As this gets larger, boundary resistance lessens.
# Defaults to screen height for vertical scrolls,
# and screen width for horizontal scrolls.
_defaultStretchLimit: Number { get }
```

### Hooks

```coffee
__shouldUpdate: ->
  #
  # Used by the component instance
  # to determine if it should re-render.
  #
  # By default, always returns false.
  # (use `forceUpdate` to re-render)
  #

__shouldCaptureOnStart: ->
  #
  # Used by the drag responder to
  # determine if it should become
  # `Responder.current`.
  #
  # Called every time a new finger
  # touches the screen.
  #
  # By default, always returns false.
  #
  # Typically, drag gestures are created
  # from `shouldCaptureOnMove` events.
  # So it's rarely necessary to override this.
  #

__canDrag: ->
  #
  # Override to customize the prerequisites
  # before drag gestures can be recognized.
  # Return false to prevent dragging.
  #
  # By default, always returns true.
  #

__canScroll: ->
  #
  # Override to customize the prerequisites
  # before scrolling is recognized.
  # Return false to prevent scrolling.
  #
  # By default, returns true when 'maxOffset' exists.
  #
  # The only time you should need to override this is
  # if you want drag gestures to still be recognized,
  # but you want scrolling to be disabled.
  #

__isScrolling: ->
  #
  # Override to customize scrolling detection.
  #
  # By default, only returns true if '_drag.offset' is animating.
  #

__isEndReached: (offset, maxOffset) ->
  #
  # Override to customize "end of content" detection.
  #
  # By default, uses the '_endThreshold' and 'maxOffset'
  # to determine if the end has been reached.
  #

__onScroll: (offset) ->
  #
  # Called whenever the 'offset' changes.
  #
  # By default, emits the 'didScroll' event.
  # When you override, you can choose when the
  # event is emitted by calling '@__super(arguments)'.
  #

__onDragStart: ->
  #
  # Called whenever the user starts dragging.
  #
  # By default, does nothing.
  #

__onDragEnd: ->
  #
  # Called whenever the user stops dragging.
  #
  # By default, does nothing.
  #

__shouldRebound: ->
  #
  # Override to customize the logic for rebound prevention.
  # Return false to prevent the rebound animation.
  #
  # By default, always returns true.
  #
```
