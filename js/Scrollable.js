var Children, Device, Draggable, NativeValue, Null, Number, NumberOrNull, Rubberband, Section, Style, Type, View, assertType, bind, clampValue, emptyFunction, isType, ref, type;

ref = require("modx"), Type = ref.Type, Device = ref.Device, Style = ref.Style, Children = ref.Children;

NativeValue = require("modx/native").NativeValue;

Number = require("Nan").Number;

View = require("modx/views").View;

emptyFunction = require("emptyFunction");

Rubberband = require("Rubberband");

assertType = require("assertType");

clampValue = require("clampValue");

Draggable = require("Draggable");

isType = require("isType");

Null = require("Null");

bind = require("bind");

Section = require("./Section");

NumberOrNull = Number.or(Null);

type = Type("Scrollable");

type.defineOptions({
  axis: Draggable.Axis.isRequired,
  offset: Number,
  endThreshold: Number.withDefault(0),
  fastThreshold: Number.withDefault(0.2),
  stretchLimit: Number,
  elasticity: Number.withDefault(0.7),
  children: Section.Kind
});

type.initArgs(function(arg) {
  var options;
  options = arg[0];
  return options.stretchLimit != null ? options.stretchLimit : options.stretchLimit = options.axis === "x" ? Device.width : Device.height;
});

type.defineStatics({
  Section: {
    get: function() {
      return Section;
    }
  },
  Row: {
    lazy: function() {
      return require("./Row");
    }
  },
  Child: {
    lazy: function() {
      return require("./Child");
    }
  }
});

type.defineReactiveValues({
  _touchable: true,
  _visibleLength: null,
  _contentLength: null,
  _reachedEnd: false
});

type.defineValues(function(options) {
  return {
    _children: null,
    _endOffset: null,
    _edgeIndex: null,
    _edgeOffsets: [],
    _fastThreshold: options.fastThreshold
  };
});

type.defineFrozenValues(function(options) {
  return {
    _endThreshold: options.endThreshold,
    _drag: Draggable({
      axis: options.axis,
      offset: options.offset,
      canDrag: (function(_this) {
        return function(gesture) {
          return _this.__canDrag(gesture);
        };
      })(this),
      shouldCaptureOnStart: (function(_this) {
        return function(gesture) {
          return _this.__shouldCaptureOnStart(gesture);
        };
      })(this)
    }),
    _edge: Rubberband({
      maxValue: options.stretchLimit,
      maxVelocity: 3,
      elasticity: options.elasticity
    })
  };
});

type.initInstance(function(options) {
  this.children = options.children || null;
});

type.defineEvents({
  didScroll: {
    offset: Number
  },
  didLayout: null,
  didReachEnd: null
});

type.defineGetters({
  axis: function() {
    return this._drag.axis;
  },
  isHorizontal: function() {
    return this._drag.isHorizontal;
  },
  gesture: function() {
    return this._drag.gesture;
  },
  isDragging: function() {
    return this._drag.isActive;
  },
  contentLength: function() {
    return this._contentLength;
  },
  visibleLength: function() {
    return this._visibleLength;
  },
  edgeOffset: function() {
    if (this._edgeIndex === null) {
      return null;
    }
    return this._edgeOffsets[this._edgeIndex] || 0;
  },
  inBounds: function() {
    return this._edgeIndex === null;
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
  }
});

type.definePrototype({
  children: {
    get: function() {
      return this._children;
    },
    set: function(newValue, oldValue) {
      if (newValue === oldValue) {
        return;
      }
      if (oldValue !== null) {
        oldValue._index = null;
        oldValue._scroll = null;
        oldValue._isVisible = null;
      }
      if (newValue === null) {
        this._children = null;
        return;
      }
      assertType(newValue, Section.Kind);
      newValue._index = 0;
      newValue._scroll = this;
      newValue._isVisible = true;
      this._children = newValue;
    }
  },
  offset: {
    get: function() {
      return 0 - this._offset.value;
    },
    set: function(offset) {
      return this._drag.offset.value = 0 - offset;
    }
  },
  minOffset: {
    get: function() {
      return this._edgeOffsets[0] || 0;
    },
    set: function(minOffset) {
      return this._edgeOffsets[0] = minOffset;
    }
  },
  maxOffset: {
    get: function() {
      return this._edgeOffsets[1] || 0;
    },
    set: function(maxOffset) {
      return this._edgeOffsets[1] = maxOffset;
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
    config.endValue = 0 - offset;
    return this._drag.offset.animate(config);
  },
  stopScrolling: function() {
    this._drag.offset.stopAnimation();
    this._edge.isRebounding && this._edge.stopRebounding();
  },
  _animationFlags: function() {
    return {
      isAnimating: this._drag.offset.isAnimating,
      isRebounding: this._edge.isRebounding
    };
  },
  _setContentLength: function(newLength) {
    if (newLength === this._contentLength) {
      return;
    }
    return this._updateEndOffset((this._contentLength = newLength), this._visibleLength);
  },
  _setVisibleLength: function(newLength) {
    if (newLength === this._visibleLength) {
      return;
    }
    return this._updateEndOffset(this._contentLength, (this._visibleLength = newLength));
  },
  _updateEndOffset: function(contentLength, visibleLength) {
    var newValue, oldValue;
    newValue = this.__computeEndOffset(contentLength, visibleLength);
    assertType(newValue, NumberOrNull);
    if (newValue === (oldValue = this._endOffset)) {
      return;
    }
    this._endOffset = newValue;
    log.it(this.__name + ".didLayout()");
    this._events.emit("didLayout");
  },
  _updateReachedEnd: function(offset, endOffset) {
    var newValue;
    newValue = this.__isEndReached(offset, endOffset);
    if (this._reachedEnd === newValue) {
      return;
    }
    if (this._reachedEnd = newValue) {
      this._events.emit("didReachEnd");
    }
  },
  _rebound: function(velocity) {
    this.stopScrolling();
    if (this._edgeIndex === 0) {
      velocity *= -1;
    }
    if (velocity > 0) {
      velocity *= 300;
    }
    log.it(this.__name + ("._rebound: {offset: " + this.offset + ", velocity: " + velocity + "}"));
    return this._edge.rebound({
      velocity: velocity,
      onEnd: this._onReboundEnd
    });
  },
  _isScrollingFast: function() {
    if (!this.__isScrolling()) {
      return false;
    }
    return this._fastThreshold < Math.abs(this.__getVelocity());
  },
  _getStartOffset: function() {
    var offset;
    offset = 0 - this._drag.offset.value;
    if (this._edgeIndex !== null) {
      if (this._edgeIndex === 0) {
        return this.edgeOffset - this._edge.resist();
      }
      return this.edgeOffset + this._edge.resist();
    }
    return clampValue(offset, this.minOffset, this.maxOffset);
  }
});

type.defineBoundMethods({
  _onDragStart: function(gesture) {
    this.stopScrolling();
    gesture._startOffset = 0 - this._getStartOffset();
    this.__onDragStart(gesture);
  },
  _onScroll: function(offset) {
    if (this.inBounds) {
      this._updateReachedEnd(offset, this._endOffset);
      this._children && this._children.updateVisibleRange();
    }
    this.__onScroll(offset);
    return this._events.emit("didScroll", [offset]);
  },
  _onReboundEnd: function(finished) {
    finished && (this._edgeIndex = null);
    return this.__onReboundEnd(finished);
  }
});

type.defineHooks({
  __shouldUpdate: emptyFunction.thatReturnsFalse,
  __shouldCaptureOnStart: function() {
    if (this._edge.isRebounding) {
      return this._edge.delta > 10;
    }
    return this._isScrollingFast();
  },
  __canDrag: emptyFunction.thatReturnsTrue,
  __canScroll: function() {
    return this._endOffset !== null;
  },
  __isScrolling: function() {
    return this._drag.offset.isAnimating;
  },
  __getVelocity: function() {
    var animation;
    animation = this._drag.offset.animation;
    if (animation) {
      return 0;
    } else {
      return animation.velocity;
    }
  },
  __isEndReached: function(offset, endOffset) {
    return (endOffset !== null) && (endOffset !== 0) && (endOffset - this._endThreshold <= offset);
  },
  __onDragStart: emptyFunction,
  __onDragEnd: function(gesture) {
    var velocity;
    if (this.inBounds) {
      return;
    }
    velocity = gesture.velocity;
    if (this._edgeIndex === 0) {
      velocity *= -1;
    }
    return this._rebound(velocity);
  },
  __onScroll: emptyFunction,
  __onReboundEnd: emptyFunction,
  __computeOffset: function(offset, minOffset, maxOffset) {
    if (this._edgeIndex === null) {
      return clampValue(offset, minOffset, maxOffset);
    }
    if (this._edgeIndex === 0) {
      return this.edgeOffset - this._edge.resist();
    }
    return this.edgeOffset + this._edge.resist();
  },
  __computeEndOffset: function(contentLength, visibleLength) {
    if (contentLength === null) {
      return null;
    }
    if (visibleLength === null) {
      return null;
    }
    return Math.max(0, contentLength - visibleLength);
  }
});

type.defineProps({
  style: Style,
  children: Children
});

type.defineReactions({
  _edgeDelta: function() {
    var maxOffset, minOffset, offset;
    offset = 0 - this._drag.offset.value;
    if (offset < (minOffset = this.minOffset)) {
      this._edgeIndex = 0;
      this._edge.delta = minOffset - offset;
    } else if (offset > (maxOffset = this.maxOffset)) {
      this._edgeIndex = 1;
      this._edge.delta = offset - maxOffset;
    } else {
      this._edgeIndex = null;
      this._edge.delta = 0;
    }
  }
});

type.defineNativeValues({
  _offset: function() {
    var offset;
    offset = 0 - this._drag.offset.value;
    offset = this.__computeOffset(offset, this.minOffset, this.maxOffset);
    assertType(offset, Number);
    return Device.round(0 - offset);
  },
  _pointerEvents: function() {
    if (this.isTouchable) {
      return "auto";
    }
    return "none";
  }
});

type.defineListeners(function() {
  this._offset.didSet(this._onScroll);
  this._drag.didGrant(this._onDragStart);
  this._drag.didEnd((function(_this) {
    return function(gesture) {
      return _this.__onDragEnd(gesture);
    };
  })(this));
  return this.didLayout((function(_this) {
    return function() {
      _this._reachedEnd = false;
      return _this._updateReachedEnd(_this._offset.value, _this._endOffset);
    };
  })(this));
});

type.defineStyles({
  container: {
    overflow: "hidden"
  },
  contents: {
    alignItems: "stretch",
    justifyContent: "flex-start",
    flexDirection: function() {
      if (this.isHorizontal) {
        return "row";
      } else {
        return "column";
      }
    },
    translateX: function() {
      if (this.isHorizontal) {
        return this._offset;
      }
    },
    translateY: function() {
      if (!this.isHorizontal) {
        return this._offset;
      }
    }
  }
});

type.render(function() {
  return View({
    style: [this.props.style, this.styles.container()],
    children: this.__renderContents(),
    pointerEvents: this._pointerEvents,
    mixins: [this._drag.touchHandlers],
    onLayout: (function(_this) {
      return function(event) {
        var key, layout;
        layout = event.nativeEvent.layout;
        key = _this.isHorizontal ? "width" : "height";
        return _this._setVisibleLength(layout[key]);
      };
    })(this)
  });
});

type.defineHooks({
  __renderContents: function() {
    if (this._children) {
      return this._children.render({
        style: this.styles.contents()
      });
    }
    return View({
      style: this.styles.contents(),
      children: this.props.children,
      onLayout: (function(_this) {
        return function(event) {
          var key, layout;
          layout = event.nativeEvent.layout;
          key = _this.isHorizontal ? "width" : "height";
          return _this._setContentLength(layout[key]);
        };
      })(this)
    });
  }
});

module.exports = type.build();

//# sourceMappingURL=map/Scrollable.map
