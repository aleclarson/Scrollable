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
  _isVisible: null
});

type.defineProperties({
  _offset: {
    value: null,
    reactive: true,
    didSet: function(newOffset, oldOffset) {
      if (newOffset === oldOffset) {
        return;
      }
      log.it(this.__name + ".offset = " + newOffset);
      return this.__onOffsetChange(newOffset, oldOffset);
    }
  },
  _length: {
    value: 0,
    reactive: true,
    didSet: function(newLength, oldLength) {
      if (newLength === oldLength) {
        return;
      }
      log.it(this.__name + ".length = " + newLength);
      return this.__onLengthChange(newLength, oldLength);
    }
  },
  _section: {
    value: null,
    didSet: function(newSection, oldSection) {
      if (newSection === oldSection) {
        return;
      }
      oldSection && this.__onRemove();
      newSection && this.__onInsert();
    }
  }
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
  scroll: function() {
    return this._section.scroll;
  },
  didLayout: function() {
    return this._didLayout.listenable;
  }
});

type.defineHooks({
  __onOffsetChange: function(newOffset) {
    var childBelow;
    if (this._length === null) {
      return;
    }
    if (childBelow = this._section.get(this.index + 1)) {
      childBelow._offset = newOffset + this._length;
    }
  },
  __onLengthChange: emptyFunction,
  __onInsert: emptyFunction,
  __onRemove: emptyFunction
});

module.exports = type.build();

//# sourceMappingURL=map/Child.map
