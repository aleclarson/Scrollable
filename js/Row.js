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
    _element: options.element
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

type.defineGetters({
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
    return this._didLayout.emit();
  }
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
    overflow: "hidden"
  }
});

module.exports = type.build();

//# sourceMappingURL=map/Row.map
