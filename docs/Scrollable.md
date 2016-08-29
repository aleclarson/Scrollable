
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
