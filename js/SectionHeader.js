var ScrollHeader, Type, View, emptyFunction, type;

View = require("modx/views").View;

Type = require("modx").Type;

emptyFunction = require("emptyFunction");

type = Type("Scrollable_SectionHeader");

type.defineOptions({
  sticky: Boolean.withDefault(false),
  length: Number.withDefault(0)
});

type.defineValues(function(options) {
  return {
    _minTop: null,
    _section: null,
    _sticky: options.sticky
  };
});

type.defineGetters({
  section: function() {
    return this._section;
  },
  scroll: function() {
    return this._section.scroll;
  }
});

type.definePrototype({
  top: {
    get: function() {
      return this._top.value;
    },
    set: function(newValue) {
      return this._top.value = newValue;
    }
  },
  length: {
    get: function() {
      return this._length.value;
    },
    set: function(newLength) {
      return this._length.value = newLength;
    }
  }
});

type.defineMethods({
  _onLayout: function(layout) {
    var length, scroll;
    scroll = this.scroll;
    this._minTop = layout[scroll.axis];
    length = layout[scroll.axis === "x" ? "width" : "height"];
    if (this._length.value > 0) {
      if (this._length.value !== length) {
        throw Error("Predicted length does not match real length!");
      }
      return;
    }
    this._length.value = length;
  }
});

type.defineNativeValues({
  _top: 0,
  _length: function(options) {
    return options.length;
  }
});

type.defineStyles({
  header: {
    flexDirection: function() {
      if (this.scroll.axis === "y") {
        return "row";
      }
    },
    position: "absolute",
    top: function() {
      return this._top;
    },
    left: 0,
    right: 0
  },
  emptyHeader: {
    alignSelf: "stretch",
    width: function() {
      if (this.scroll.axis === "x") {
        return this._length;
      }
    },
    height: function() {
      if (this.scroll.axis === "y") {
        return this._length;
      }
    }
  }
});

type.render(function() {
  return View({
    style: this.styles.header(),
    children: this.__renderContent(),
    onLayout: (function(_this) {
      return function(event) {
        return _this._onLayout(event.nativeEvent.layout);
      };
    })(this)
  });
});

type.shouldUpdate(function() {
  return false;
});

type.defineMethods({
  renderEmpty: function() {
    return View({
      style: this.styles.emptyHeader()
    });
  }
});

type.defineHooks({
  __renderContent: emptyFunction.thatReturnsFalse
});

module.exports = ScrollHeader = type.build();

//# sourceMappingURL=map/SectionHeader.map
