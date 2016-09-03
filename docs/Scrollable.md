
# Scrollable ![](https://img.shields.io/badge/last_updated-08/20/2016-yellow.svg?style=flat)

The `Scrollable` type provides the core functionality of any scrollable view.

```coffee
Scrollable = require "Scrollable"
```

### Options

```coffee
# The directional axis upon which scrolling occurs.
axis: Draggable.Axis.isRequired

# The starting value of 'offset'.
offset: Number

# The maximum value of 'offset'.
# Computed on-the-fly if undefined.
maxOffset: Number

# Number of pixels from the end of the scrollable
# area until 'didReachEnd' is emitted.
endThreshold: Number.withDefault 0

# Controls the boundary resistance.
elasticity: Number.withDefault 0.7

# Limits the distance from a boundary.
stretchLimit: Number
```

### Properties

```coffee
# Equals 'options.axis'
axis: Draggable.Axis { get }

# The active gesture
gesture: Draggable.Gesture { get }

# Equals true if the user is dragging
isDragging: Boolean { get }

# The current scroll position
offset: Number { get, set }

# The minimum value of 'offset'
minOffset: Number { get }

# The maximum value of 'offset'
maxOffset: Number { get }

# The length of the scrollable contents
contentLength: Number { get }

# The length of the viewport
visibleLength: Number { get }

# Equals false if the 'offset'
# is past 'minOffset' or 'maxOffset'
inBounds: Boolean { get }

# Equals true if a rebound animation is active
isRebounding: Boolean { get }

# When set to false, the view
# is unresponsive to any touches.
isTouchable: Boolean { get, set }
```

### Events

```coffee
scroll.didLayout (maxOffset, oldMaxOffset) ->
  # Emits whenever 'maxOffset' changes.

scroll.didScroll (offset) ->
  # Emits whenever 'offset' changes.

scroll.didReachEnd ->
  # Emits whenever 'endThreshold' is reached.
```

Learn more about the [`Event`](https://github.com/aleclarson/Event) type.

### Methods

```coffee
# Animates the 'offset' using the
# provided animation config.
animation = scroll.scrollTo offset, config

# Stops any active scrolling.
scroll.stopScrolling()
```

### Styles

```coffee
# Defaults for the inner container.
content:
  alignItems: "stretch"
  justifyContent: "flex-start"
  flexDirection: -> if @isHorizontal then "row" else "column"
  translateX: # <= Reacts to 'offset' if 'axis' equals "x"
  translateY: # <= Reacts to 'offset' if 'axis' equals "y"

# Defaults for the outer container.
container:
  overflow: "hidden"
```

### Subclass Hooks

The following methods are designed with subclassing in mind.

#### `__shouldUpdate: (gesture) -> bool`

Used by the component instance to determine if it should re-render.

By default, always returns `false`. (call `forceUpdate` to re-render)

#### `__shouldCaptureOnStart: (gesture) -> bool`

Used by the drag responder to determine if it should become `Responder.current`.

Called every time a new finger touches the screen.

By default, always returns `false`.

It's rarely necessary to override this, because drag
gestures are typically created from `shouldCaptureOnMove` events.

#### `__canDrag: () -> bool`

Override to customize the prerequisites
before drag gestures can be recognized.
Return false to prevent dragging.

By default, always returns `true`.

#### `__canScroll: () -> bool`

Override to customize the prerequisites
before scrolling is recognized.
Return false to prevent scrolling.

By default, returns `true` when `maxOffset` exists.

The only time you should need to override this is
if you want drag gestures to still be recognized,
but you want scrolling to be disabled.

#### `__isScrolling: () -> bool`

Override to customize scrolling detection.

By default, only returns `true` if `_drag.offset` is animating.

#### `__isEndReached: (offset, maxOffset) -> bool`

Override to customize "end of content" detection.

By default, uses the `_endThreshold` and `maxOffset`
to determine if the end has been reached.

#### `__onDragStart: (gesture) -> void`

Called whenever the user starts dragging.

#### `__onDragEnd: (gesture) -> void`

Called whenever the user stops dragging.

#### `__shouldRebound: () -> bool`

Override to customize the logic for rebound prevention.

Return `false` to prevent the rebound animation.

By default, always returns `true`.

#### `__onScroll: (offset, maxOffset) -> void`

Called whenever `offset` changes.

#### `__computeOffset: (offset, minOffset, maxOffset) -> number`

Called whenever `_drag.offset` changes.

Must return a `Number` representing the new `offset`.

**NOTE:** This is called within a [`Reaction`](https://github.com/aleclarson/Reaction)!

#### `__childWillAttach: (child, index) -> Section | Row`

Called before a new child is added.

Must return the given child, or wrap it with a `Section` or `Row` constructor.

**NOTE:** Only available after `createChildren` is called.

#### `__childDidAttach: (child) -> void`

Called after a new child is added.

**NOTE:** Only available after `createChildren` is called.

#### `__childWillDetach: (child) -> void`

Called before a child is removed.

**NOTE:** Only available after `createChildren` is called.

#### `__childDidLayout: (child) -> void`

Called after a child's `length` is changed.

**NOTE:** Only available after `createChildren` is called.

#### `__renderEmpty`

Renders a `View` when no children exist.

**NOTE:** Only available after `createChildren` is called.

#### `__renderHeader`

Renders a `View` before the children.

**NOTE:** Only available after `createChildren` is called.

#### `__renderFooter`

Renders a `View` after the header & children.

**NOTE:** Only available after `createChildren` is called.

#### `__renderOverlay`

Renders a `View` after the header, children, & footer.

Use `position: "absolute"` to achieve an overlay effect.

**NOTE:** Only available after `createChildren` is called.
