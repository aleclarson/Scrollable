var Event, Promise, Type, emptyFunction, type;

require("isDev");

Type = require("modx").Type;

emptyFunction = require("emptyFunction");

Promise = require("Promise");

Event = require("Event");

type = Type("Scrollable_Child");

type.defineValues(function() {
  return {
    _mounting: null,
    _didLayout: Event()
  };
});

type.defineReactiveValues({
  _index: null,
  _offset: null,
  _length: null,
  _isVisible: null,
  _section: null
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
  isMounting: function() {
    return this._mounting !== null;
  },
  isFirst: function() {
    return this.index === this._section.startIndex;
  },
  isLast: function() {
    return this.index === this._section.endIndex;
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
  _setSection: function(section) {
    var oldSection;
    if (section !== (oldSection = this._section)) {
      if (oldSection) {
        this.__sectionWillRemove();
      }
      if (!section) {
        return;
      }
      this._section = section;
      this.__sectionDidInsert();
    }
  },
  _setOffset: function(offset) {
    var oldOffset;
    if (offset !== (oldOffset = this._offset)) {
      this._offset = offset;
      this.__offsetDidChange(offset, oldOffset);
    }
  },
  _setLength: function(length) {
    var oldLength;
    if (length !== (oldLength = this._length)) {
      this._length = length;
      this.__lengthDidChange(length, oldLength);
    }
  },
  _mountWillBegin: function() {
    log.it(this.__name + "._mountWillBegin()");
    this._mounting = Promise.defer();
    this.__mountWillBegin();
    return this._mounting.promise;
  },
  _mountDidFinish: function() {
    log.it(this.__name + "._mountDidFinish()");
    this._mounting.resolve();
    this._mounting = null;
  },
  _onLayout: function(offset, length) {
    var childBelow;
    if (this._section === null) {
      return;
    }
    if (offset === null) {
      return;
    }
    if (length === null) {
      return;
    }
    if (childBelow = this._section.get(this.index + 1)) {
      childBelow._setOffset(offset + length);
    }
  }
});

type.defineHooks({
  __indexDidChange: emptyFunction,
  __offsetDidChange: function(offset) {
    this._onLayout(offset, this._length);
  },
  __lengthDidChange: function(length) {
    this._onLayout(this._offset, length);
  },
  __mountWillBegin: emptyFunction,
  __mountWillFinish: emptyFunction,
  __sectionDidInsert: emptyFunction,
  __sectionWillRemove: function() {
    this._index = null;
    this._setOffset(null);
    this._setLength(null);
    this._isVisible = null;
    this._mounting = null;
  }
});

type.didMount(function() {
  var mounting;
  if (isDev && !this._mounting) {
    throw Error("'_mounting' must exist before the 'didMount' phase!");
  }
  mounting = this.__mountWillFinish();
  if (Promise.isPending(mounting)) {
    mounting.then((function(_this) {
      return function() {
        return _this._mountDidFinish();
      };
    })(this));
    return;
  }
  this._mountDidFinish();
});

module.exports = type.build();

//# sourceMappingURL=map/Child.map
