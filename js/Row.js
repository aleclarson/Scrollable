var Element, Event, Type, View, assert, emptyFunction, ref, type;

ref = require("modx"), Type = ref.Type, Element = ref.Element;

View = require("modx/views").View;

emptyFunction = require("emptyFunction");

assert = require("assert");

Event = require("Event");

type = Type("Scrollable_Row");

type.defineOptions({
  key: String,
  props: Object,
  render: Function.Kind,
  element: Element
});

type.defineValues(function(options) {
  return {
    _key: options.key,
    _props: options.props,
    _render: options.render,
    _element: options.element,
    _didLayout: Event()
  };
});

type.defineValues({
  __renderContents: function() {
    if (this._element) {
      return function() {
        return this._element;
      };
    } else if (this._render) {
      return function() {
        return this._render(this._props);
      };
    }
  }
});

type.defineReactiveValues({
  _index: null,
  _offset: null,
  _length: 0,
  _isVisible: null
});

type.defineProperties({
  _section: {
    value: null,
    reactive: true,
    didSet: function(newValue, oldValue) {
      if (newValue) {
        assert(oldValue === null, "'this._section' must be null before setting to a non-null value!");
        return this.__onInsert();
      } else if (oldValue) {
        return this.__onRemove();
      }
    }
  }
});

type.defineGetters({
  index: function() {
    return this._index;
  },
  offset: function() {
    return this._offset;
  },
  length: function() {
    return this._length;
  },
  isVisible: function() {
    return this._isVisible;
  },
  section: function() {
    return this._section;
  },
  scroll: function() {
    return this._section.scroll;
  },
  didLayout: function() {
    return this._didLayout.listenable;
  }
});

type.defineMethods({
  _onLayout: function(layout) {
    var scroll;
    scroll = this.scroll;
    this._offset = layout[scroll.axis];
    this._length = layout[scroll.axis === "x" ? "width" : "height"];
    this._isVisible = scroll._isAreaVisible(this._offset, this._length);
    return this._didLayout.emit();
  }
});

type.defineHooks({
  __onInsert: emptyFunction,
  __onRemove: emptyFunction
});

type.shouldUpdate(function() {
  return false;
});

type.render(function() {
  return View({
    key: this._key,
    style: this.styles.container(),
    children: this.__renderContents(),
    onLayout: (function(_this) {
      return function(event) {
        return _this._onLayout(event.nativeEvent.layout);
      };
    })(this)
  });
});

type.willMount(function() {
  return this._props && (this._props.row = this);
});

type.willUnmount(function() {
  return this._props && (this._props.row = null);
});

type.defineHooks({
  __renderContents: emptyFunction.thatReturnsFalse
});

type.defineStyles({
  container: {
    overflow: "hidden",
    opacity: function() {
      return this.opacity;
    }
  }
});

module.exports = type.build();

//# sourceMappingURL=map/Row.map
