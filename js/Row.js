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

type.defineMethods({
  _onLayout: function(layout) {
    var childBelow, newLength, oldLength;
    newLength = layout[this.scroll.isHorizontal ? "width" : "height"];
    if (newLength === (oldLength = this._length)) {
      return;
    }
    this._length = newLength;
    if (this.index === 0) {
      this._offset = 0;
    } else if (this._offset !== null) {
      if (childBelow = this._section.get(this.index + 1)) {
        childBelow._offset = this._offset + newLength;
      }
    }
    this._section._length += newLength - oldLength;
    this._didLayout.emit();
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

type.willUpdate(function() {
  return log.it(this.__name + ".willUpdate()");
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
    overflow: "hidden"
  }
});

module.exports = type.build();

//# sourceMappingURL=map/Row.map
