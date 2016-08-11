var Event, Type, emptyFunction, type;

emptyFunction = require("emptyFunction");

Event = require("Event");

Type = require("Type");

type = Type("Scrollable_Child");

type.defineValues({
  _section: null,
  _didLayout: function() {
    return Event();
  }
});

type.defineReactiveValues({
  _index: null,
  _offset: null,
  _length: null,
  _isVisible: null
});

type.defineGetters({
  isVisible: function() {
    return this._isVisible;
  },
  index: function() {
    return this._index;
  },
  offset: function() {
    return this._offset;
  },
  length: function() {
    return this._length;
  },
  section: function() {
    return this._section;
  },
  didLayout: function() {
    return this._didLayout.listenable;
  }
});

type.defineMethods({
  _setSection: function(newValue) {
    var oldValue;
    oldValue = this._section;
    if (newValue && oldValue) {
      throw Error("Must set section to null first!");
    }
    if (this._section = newValue) {
      this.__onInsert();
    } else if (oldValue) {
      this.__onRemove();
    }
  }
});

type.defineHooks({
  __onInsert: emptyFunction,
  __onRemove: emptyFunction
});

module.exports = type.build();

//# sourceMappingURL=map/Child.map
