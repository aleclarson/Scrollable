var Component, Draggable, NativeValue, Rubberband, emptyFunction, ref, ref1, roundToScreenScale, screenHeight, screenWidth, type;

ref = require("device"), screenWidth = ref.screenWidth, screenHeight = ref.screenHeight, roundToScreenScale = ref.roundToScreenScale;

ref1 = require("modx"), Component = ref1.Component, NativeValue = ref1.NativeValue;

emptyFunction = require("emptyFunction");

Rubberband = require("Rubberband");

Draggable = require("Draggable");

type = Component.Type("VirtualScroll");

type.defineOptions({
  axis: Draggable.Axis.isRequired,
  offset: Number,
  maxOffset: Number,
  endThreshold: Number.withDefault(0),
  elasticity: Number.withDefault(0.7),
  stretchLimit: Number
});

type.defineFrozenValues({
  _endThreshold: fromArgs("endThreshold"),
  _offset: function() {
    return NativeValue((function(_this) {
      return function() {
        return _this._computeOffset();
      };
    })(this));
  },
  _pointerEvents: function() {
    return NativeValue((function(_this) {
      return function() {
        if (_this.isTouchable) {
          return "auto";
        }
        return "none";
      };
    })(this));
  },
  _drag: function(options) {
    return Draggable({
      axis: options.axis,
      offset: options.offset,
      inverse: true,
      canDrag: (function(_this) {
        return function(gesture) {
          return _this.__canDrag(gesture);
        };
      })(this),
      shouldCaptureOnStart: this._shouldCaptureOnStart
    });
  }
});

type.defineReactiveValues({
  _touchable: true,
  _edgeOffset: null,
  _visibleLength: null,
  _contentLength: null,
  _reachedEnd: false
});

type.defineValues({
  _maxOffset: function(options) {
    return options.maxOffset != null ? options.maxOffset : options.maxOffset = null;
  },
  _edge: function(options) {
    if (options.stretchLimit == null) {
      options.stretchLimit = this._defaultStretchLimit;
    }
    return Rubberband({
      elasticity: options.elasticity,
      maxValue: options.stretchLimit
    });
  }
});

type.defineEvents({
  didLayout: {
    maxOffset: Number,
    oldMaxOffset: Number
  },
  didScroll: {
    offset: Number
  },
  didReachEnd: null
});

type.defineGetters({
  axis: function() {
    return this._drag.axis;
  },
  gesture: function() {
    return this._drag.gesture;
  },
  isDragging: function() {
    return this._drag.isActive;
  },
  minOffset: function() {
    return 0;
  },
  maxOffset: function() {
    return this._maxOffset;
  },
  inBounds: function() {
    return this._edge.distance === 0;
  },
  isRebounding: function() {
    return this._edge.isRebounding;
  },
  didDragReject: function() {
    return this._drag.didReject;
  },
  didDragStart: function() {
    return this._drag.didGrant;
  },
  didDragEnd: function() {
    return this._drag.didEnd;
  },
  didTouchStart: function() {
    return this._drag.didTouchStart;
  },
  didTouchMove: function() {
    return this._drag.didTouchMove;
  },
  didTouchEnd: function() {
    return this._drag.didTouchEnd;
  },
  _defaultStretchLimit: function() {
    if (this.axis === "x") {
      return screenWidth.get();
    }
    return screenHeight.get();
  }
});

type.definePrototype({
  offset: {
    get: function() {
      return this._offset.value;
    },
    set: function(offset) {
      return this._drag.offset.value = offset;
    }
  },
  contentLength: {
    get: function() {
      return this._contentLength;
    },
    set: function(newLength, oldLength) {
      if (newLength === oldLength) {
        return;
      }
      this._contentLength = newLength;
      return this._updateMaxOffset();
    }
  },
  visibleLength: {
    get: function() {
      return this._visibleLength;
    },
    set: function(newLength, oldLength) {
      if (newLength === oldLength) {
        return;
      }
      this._visibleLength = newLength;
      return this._updateMaxOffset();
    }
  },
  isTouchable: {
    get: function() {
      return this._touchable;
    },
    set: function(isTouchable) {
      return this._touchable = isTouchable;
    }
  }
});

type.defineMethods({
  scrollTo: function(offset, config) {
    assertType(offset, Number);
    assertType(config, Object);
    config.endValue = offset;
    return this._drag.offset.animate(config);
  },
  stopScrolling: function() {
    this._drag.offset.stopAnimation();
    this._edge.isRebounding && this._edge.stopRebounding();
  },
  _computeOffset: function() {
    var offset;
    offset = this._drag.offset.value;
    this._edgeOffset = this._getEdgeOffset(offset, this.maxOffset);
    if (!this.inBounds) {
      if (this._edgeOffset === this.maxOffset) {
        this._edge.offset = offset - this.maxOffset;
        offset = this._edgeOffset + this._edge.distance;
      } else {
        this._edge.offset = this.minOffset - offset;
        offset = this._edgeOffset - this._edge.distance;
      }
    }
    return roundToScreenScale(offset);
  },
  _getEdgeOffset: function(offset, maxOffset) {
    if (offset < this.minOffset) {
      return this.minOffset;
    }
    if (offset > maxOffset) {
      return maxOffset;
    }
    return null;
  },
  _updateMaxOffset: function() {
    var newValue, oldValue;
    newValue = null;
    if ((this.contentLength != null) && (this.visibleLength != null)) {
      newValue = Math.max(0, this.contentLength - this.visibleLength);
    }
    oldValue = this._maxOffset;
    if (newValue === oldValue) {
      return;
    }
    this._maxOffset = newValue;
    this._reachedEnd = false;
    this._updateReachedEnd(this._offset.value);
    return this._events.emit("didLayout", [newValue, oldValue]);
  },
  _updateReachedEnd: function() {
    var maxOffset, newValue;
    maxOffset = this._maxOffset;
    newValue = this.__isEndReached();
    if (this._reachedEnd === newValue) {
      return;
    }
    if (this._reachedEnd = newValue) {
      this._events.emit("didReachEnd");
    }
  },
  _shouldRebound: function(velocity) {
    if (this.inBounds) {
      return false;
    }
    return this.__shouldRebound(velocity);
  }
});

type.defineBoundMethods({
  _shouldCaptureOnStart: function(gesture) {
    var velocity;
    if (this.__isScrolling(gesture)) {
      velocity = this._drag.offset.animation.velocity;
      return Math.abs(velocity) > 0.02;
    }
    if (this._edge.isRebounding) {
      return this._edge.distance > 10;
    }
    return this.__shouldCaptureOnStart(gesture);
  },
  _onScroll: function(offset) {
    log.it(this.__name + "._onScroll: " + offset);
    this.inBounds && this._updateReachedEnd(offset, this.maxOffset);
    this.__onScroll(offset, this.maxOffset);
  },
  _onDragStart: function(gesture) {
    this.stopScrolling();
    this.__onDragStart(gesture);
  },
  _onDragEnd: function(gesture) {
    var velocity;
    velocity = gesture.velocity;
    if (this._shouldRebound(velocity)) {
      this._edge.rebound(velocity);
      return;
    }
    this.__onDragEnd(velocity, gesture);
  }
});

type.defineHooks({
  __shouldUpdate: emptyFunction.thatReturnsFalse,
  __shouldCaptureOnStart: emptyFunction.thatReturnsFalse,
  __canDrag: emptyFunction.thatReturnsTrue,
  __canScroll: function() {
    return this._maxOffset !== null;
  },
  __isScrolling: function() {
    return this._drag.offset.isAnimating;
  },
  __isEndReached: function(offset, maxOffset) {
    return (maxOffset !== null) && (maxOffset !== 0) && (maxOffset - this._endThreshold <= offset);
  },
  __onScroll: function(offset) {
    return this._events.emit("didScroll", [offset]);
  },
  __onDragStart: emptyFunction,
  __onDragEnd: emptyFunction,
  __shouldRebound: emptyFunction.thatReturnsTrue
});

type.defineListeners(function() {
  this._offset.didSet(this._onScroll);
  this._drag.didGrant(this._onDragStart);
  return this._drag.didEnd(this._onDragEnd);
});

type.defineStyles({
  content: {
    alignItems: "stretch",
    justifyContent: "flex-start",
    flexDirection: function() {
      if (this.axis === "x") {
        return "row";
      } else {
        return "column";
      }
    },
    translateX: function() {
      if (this.axis === "x") {
        return this._offset;
      }
    },
    translateY: function() {
      if (this.axis === "y") {
        return this._offset;
      }
    }
  },
  container: {
    overflow: "hidden"
  }
});

type.willUnmount(function() {
  this.visibleLength = null;
  return this.contentLength = null;
});

type.render(function() {
  return View({
    style: this.styles.container(),
    children: this.__renderContent(),
    pointerEvents: this._pointerEvents,
    mixins: [this._drag.touchHandlers],
    onLayout: (function(_this) {
      return function(event) {
        var key, layout;
        layout = event.nativeEvent.layout;
        key = _this.axis === "x" ? "width" : "height";
        return _this.visibleLength = layout[key];
      };
    })(this)
  });
});

type.defineHooks({
  __renderChildren: emptyFunction,
  __renderContent: function() {
    return View({
      children: this.__renderChildren(),
      onLayout: (function(_this) {
        return function(event) {
          var key, layout;
          layout = event.nativeEvent.layout;
          key = _this.axis === "x" ? "width" : "height";
          return _this.contentLength = layout[key];
        };
      })(this)
    });
  }
});

module.exports = type.build();

//# sourceMappingURL=map/VirtualScroll.map
