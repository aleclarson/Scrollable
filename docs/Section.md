
# Scrollable.Section ![](https://img.shields.io/badge/last_updated-08/20/2016-yellow.svg?style=flat)

The `Section` type is the stateful container for a group of `Row` and/or `Section` instances.

```coffee
{Section} = require "Scrollable"
```

**TODO:** Go into depth...

### Subclass Hooks

```coffee
# Renders when the section has no children.
__renderEmpty: ->
  return element or false

# Renders above all children.
__renderHeader: ->
  return element or false

# Renders below all children.
__renderFooter: ->
  return element or false

# You must apply {position: "absolute"}
# manually to achieve an overlay effect.
__renderOverlay: ->
  return element or false

# Called before a child is added.
# Supports wrapping the child with a Row/Section.
__childWillAttach: (child, index) ->
  return child

# Called after a child is added.
__childDidAttach: (child) ->
  return

# Called before a child is removed.
__childWillDetach: (child) ->
  return

# Called when a child's length is changed.
__childDidLayout: (child, lengthChange) ->
  return

# Called from within 'removeAll'.
__onRemoveAll: ->
  return

# Returns the area (of this section) that is visible to the user.
__getVisibleArea: ->
  return {startOffset, endOffset}
```
