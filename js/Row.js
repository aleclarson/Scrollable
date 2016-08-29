var Element, Event, ScrollChild, Type, View, emptyFunction, ref, type;

ref = require("modx"), Type = ref.Type, Element = ref.Element;

View = require("modx/views").View;

emptyFunction = require("emptyFunction");

Event = require("Event");

ScrollChild = require("./Child");

type = Type("Scrollable_Row");

type.inherits(ScrollChild);

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
    _root: null
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

type.defineBoundMethods({
  _rootDidRef: function(view) {
    return this._root = view ? view.child : null;
  },
  _rootDidLayout: function(event) {
    var layout, newLength, oldLength;
    layout = event.nativeEvent.layout;
    newLength = layout[this.scroll.isHorizontal ? "width" : "height"];
    if (newLength === (oldLength = this._length)) {
      return;
    }
    this._setLength(newLength);
    this._section._childDidLayout(this, newLength - oldLength);
    this._didLayout.emit();
  }
});

type.defineMethods({
  attachRoot: function() {
    return this._root.setNativeProps({
      style: {
        position: "relative",
        opacity: 1
      }
    });
  },
  detachRoot: function() {
    return this._root.setNativeProps({
      style: {
        position: "absolute",
        opacity: 0
      }
    });
  }
});

type.overrideMethods({
  __lengthDidChange: function(length) {
    if (length !== null) {
      this.isFirst && (this._offset = 0);
    }
    return this.__super(arguments);
  }
});

type.render(function() {
  return View({
    key: this._key,
    ref: this._rootDidRef,
    style: this.styles.container(),
    children: this.__renderContents(),
    onLayout: this._rootDidLayout
  });
});

type.willMount(function() {
  return this.props.row = this;
});

type.willReceiveProps(function(props) {
  return props.row = this;
});

type.defineHooks({
  __renderContents: emptyFunction.thatReturnsFalse
});

type.defineStyles({
  container: {
    position: "absolute",
    overflow: "hidden",
    opacity: 0
  }
});

module.exports = type.build();

//# sourceMappingURL=map/Row.map
