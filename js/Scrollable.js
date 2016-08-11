var ArrayOf, Device, Draggable, Element, Nan, NativeValue, Null, Rubberband, Section, Type, View, assertType, clampValue, emptyFunction, isType, ref, type;

ref = require("modx"), Type = ref.Type, Device = ref.Device, Element = ref.Element;

NativeValue = require("modx/native").NativeValue;

View = require("modx/views").View;

emptyFunction = require("emptyFunction");

Rubberband = require("Rubberband");

assertType = require("assertType");

clampValue = require("clampValue");

Draggable = require("Draggable");

ArrayOf = require("ArrayOf");

isType = require("isType");

Null = require("Null");

Nan = require("Nan");

Section = require("./Section");

type = Type("Scrollable");

type.defineOptions({
  axis: Draggable.Axis.isRequired,
  offset: Number,
  endThreshold: Number.withDefault(0),
  visibleThreshold: Number.withDefault(0),
  stretchLimit: Number,
  elasticity: Number.withDefault(0.7),
  section: Section
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
    visibleThreshold: options.visibleThreshold,
    _section: options.section,
    _edgeOffset: null,
    _maxOffset: null,
    __renderContent: options.section ? this._renderSection : void 0
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
      shouldCaptureOnStart: this._shouldCaptureOnStart
    }),
    _edge: Rubberband({
      maxValue: options.stretchLimit != null ? options.stretchLimit : options.stretchLimit = this._defaultStretchLimit,
      elasticity: options.elasticity
    }),
    _edgeDelta: NativeValue((function(_this) {
      return function() {
        var maxOffset, minOffset, offset;
        offset = 0 - _this._drag.offset.value;
        if (offset < (minOffset = _this.minOffset)) {
          _this._edgeOffset = minOffset;
          _this._edge.delta = minOffset - offset;
        } else if (offset > (maxOffset = _this._maxOffset || 0)) {
          _this._edgeOffset = maxOffset;
          _this._edge.delta = offset - maxOffset;
        } else {
          _this._edgeOffset = null;
          _this._edge.delta = 0;
        }
      };
    })(this)),
    _offset: NativeValue((function(_this) {
      return function() {
        var maxOffset, minOffset, offset;
        offset = 0 - _this._drag.offset.value;
        minOffset = _this.minOffset;
        maxOffset = _this._maxOffset || 0;
        offset = _this.__computeOffset(offset, minOffset, maxOffset);
        if (Nan.test(offset)) {
          throw Error("Unexpected NaN value!");
        }
        if (!isType(offset, Number)) {
          throw TypeError("'__computeOffset' must return a Number!");
        }
        return Device.round(0 - offset);
      };
    })(this)),
    _pointerEvents: NativeValue((function(_this) {
      return function() {
        if (_this.isTouchable) {
          return "auto";
        }
        return "none";
      };
    })(this))
  };
});

type.initInstance(function(arg) {
  var section;
  section = arg.section;
  section._isVisible = true;
  section._index = 0;
  return section._scroll = this;
});

type.defineEvents({
  didLayout: {
    newValue: [Number, Null],
    oldValue: [Number, Null]
  },
  didScroll: {
    offset: Number
  },
  didReachEnd: null
});

type.defineGetters({
  section: function() {
    return this._section;
  },
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
  contentLength: function() {
    return this._contentLength;
  },
  visibleLength: function() {
    return this._visibleLength;
  },
  inBounds: function() {
    return this._edge.delta === 0;
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
      return Device.width;
    }
    return Device.height;
  }
});

type.definePrototype({
  offset: {
    get: function() {
      return 0 - this._offset.value;
    },
    set: function(offset) {
      return this._drag.offset.value = 0 - offset;
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
  _setContentLength: function(newLength) {
    var oldLength;
    oldLength = this._contentLength;
    if (newLength === oldLength) {
      return;
    }
    this._contentLength = newLength;
    return this._updateMaxOffset();
  },
  _setVisibleLength: function(newLength) {
    var oldLength;
    oldLength = this._visibleLength;
    if (newLength === oldLength) {
      return;
    }
    this._visibleLength = newLength;
    return this._updateMaxOffset();
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
    this._updateReachedEnd(this._offset.value, newValue);
    return this._events.emit("didLayout", [newValue, oldValue]);
  },
  _updateReachedEnd: function(offset, maxOffset) {
    var newValue;
    newValue = this.__isEndReached(offset, maxOffset);
    if (this._reachedEnd === newValue) {
      return;
    }
    if (this._reachedEnd = newValue) {
      this._events.emit("didReachEnd");
    }
  },
  _shouldRebound: function(gesture) {
    if (this.inBounds) {
      return false;
    }
    return this.__shouldRebound(gesture);
  },
  _rebound: function(arg) {
    var maxOffset, velocity;
    velocity = arg.velocity;
    maxOffset = this._maxOffset || 0;
    if (this.offset > maxOffset) {
      velocity *= -1;
    }
    return this._edge.rebound(velocity);
  }
});

type.defineBoundMethods({
  _shouldCaptureOnStart: function(gesture) {
    var velocity;
    if (this._edge.isRebounding) {
      log.it("edge.delta = " + this._edge.delta);
      return this._edge.delta > 10;
    }
    if (this.__isScrolling(gesture)) {
      velocity = this._drag.offset.animation.velocity;
      return Math.abs(velocity) > 0.02;
    }
    return this.__shouldCaptureOnStart(gesture);
  },
  _onScroll: function(offset) {
    var maxOffset;
    maxOffset = this._maxOffset || 0;
    if (this.inBounds) {
      this._updateReachedEnd(offset, maxOffset);
      this._section && this._section._getVisibleRange();
    }
    this.__onScroll(offset, maxOffset);
    return this._events.emit("didScroll", [offset]);
  },
  _onDragStart: function(gesture) {
    var delta, offset;
    this.stopScrolling();
    offset = 0 - this._drag.offset.value;
    delta = this._edge.delta;
    if (delta > 0) {
      if (offset < this.minOffset) {
        delta *= -1;
      }
      offset = this._edgeOffset + delta;
    } else {
      offset = clampValue(offset, this.minOffset, this._maxOffset || 0);
    }
    offset *= -1;
    this._drag.offset._value = gesture._startOffset = offset;
    this.__onDragStart(gesture);
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
  __onDragStart: emptyFunction,
  __onDragEnd: function(gesture) {
    if (this._shouldRebound(gesture)) {
      return this._rebound(gesture);
    }
  },
  __shouldRebound: emptyFunction.thatReturnsTrue,
  __onScroll: emptyFunction,
  __computeOffset: function(offset, minOffset, maxOffset) {
    var delta;
    if (this._edgeOffset === null) {
      return clampValue(offset, minOffset, maxOffset);
    }
    delta = this._edge.resist();
    if (offset < minOffset) {
      delta *= -1;
    }
    return this._edgeOffset + delta;
  }
});

type.propTypes = type.defineListeners(function() {
  this._offset.didSet(this._onScroll);
  this._drag.didGrant(this._onDragStart);
  return this._drag.didEnd((function(_this) {
    return function(gesture) {
      return _this.__onDragEnd(gesture);
    };
  })(this));
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
        return _this._setVisibleLength(layout[key]);
      };
    })(this)
  });
});

type.defineMethods({
  _renderSection: function() {
    return this._section.render({
      style: this.styles.content()
    });
  }
});

type.defineHooks({
  __renderContent: function() {
    return View({
      style: this.styles.content(),
      children: this.props.children,
      onLayout: (function(_this) {
        return function(event) {
          var key, layout;
          layout = event.nativeEvent.layout;
          key = _this.axis === "x" ? "width" : "height";
          return _this._setContentLength(layout[key]);
        };
      })(this)
    });
  }
});

module.exports = type.build();

//# sourceMappingURL=map/Scrollable.map
