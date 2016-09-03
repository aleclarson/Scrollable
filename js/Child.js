var Event, Promise, Type, concealedStyle, emptyFunction, revealedStyle, type;

Type = require("modx").Type;

emptyFunction = require("emptyFunction");

Promise = require("Promise");

Event = require("Event");

revealedStyle = {
  position: "relative",
  opacity: 1
};

concealedStyle = {
  position: "absolute",
  opacity: 0
};

type = Type("Scrollable_Child");

type.defineValues({
  _root: null,
  _rootStyle: revealedStyle,
  _mounting: null,
  _mountDeps: null,
  _didLayout: function() {
    return Event();
  }
});

type.defineReactiveValues({
  _section: null,
  _index: null,
  _offset: null,
  _length: null,
  _isRevealed: false,
  _isConcealed: false,
  _inVisibleArea: null
});

type.willMount(function() {
  return this._mountDeps = this.__getMountDeps();
});

type.didMount(function() {
  return this._mounting && this._mounting.resolve();
});

type.defineGetters({
  index: function() {
    return this._index;
  },
  startOffset: function() {
    return this._offset;
  },
  endOffset: function() {
    return this._offset + this._length;
  },
  length: function() {
    return this._length;
  },
  isMounted: function() {
    return this._mounting && this._mounting.promise.isFulfilled;
  },
  isRevealed: function() {
    return this._isRevealed;
  },
  isConcealed: function() {
    return this._isConcealed;
  },
  isConcealedByParent: function() {
    return this._section && !this._section.isRevealed;
  },
  inVisibleArea: function() {
    return this._inVisibleArea;
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

type.defineBoundMethods({
  _rootDidRef: function(view) {
    this._root = view;
  }
});

type.defineMethods({
  reveal: function() {
    if (!this._isConcealed) {
      return;
    }
    this._isConcealed = false;
    this._rootStyle = revealedStyle;
    if (this._root && this.isMounted) {
      this.isConcealedByParent || this._reveal();
    }
  },
  conceal: function() {
    if (this._isConcealed) {
      return;
    }
    this._isConcealed = true;
    this._rootStyle = concealedStyle;
    if (this._root && this.isMounted) {
      this._root.setNativeProps({
        style: concealedStyle
      });
      this.__onConceal();
    }
  },
  _reveal: function() {
    if (isDev) {
      if (this._isRevealed) {
        return console.warn("Already revealed!");
      }
      if (this._offset !== null) {
        return console.warn("'_offset' cannot be set before '__onReveal'!");
      }
    }
    this._isRevealed = true;
    this._root.setNativeProps({
      style: revealedStyle
    });
    this.__onReveal();
  },
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
      log.it(this.__name + ".offset = " + offset);
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
  _trackMounting: function() {
    var promise, ref, resolve;
    if (this._mounting) {
      return this._mounting.promise;
    }
    ref = Promise.defer(), resolve = ref.resolve, promise = ref.promise;
    promise = promise.then((function(_this) {
      return function() {
        return _this._mountDeps;
      };
    })(this)).then((function(_this) {
      return function() {
        return _this.__onMountFinish();
      };
    })(this));
    this._mounting = {
      resolve: resolve,
      promise: promise
    };
    return promise;
  },
  _onLayout: function(offset, length) {
    var childBelow;
    if (this._isRevealed && this._section !== null && offset !== null && length !== null) {
      childBelow = this._section.get(this.index + 1);
      if (childBelow && childBelow.isRevealed) {
        childBelow._setOffset(offset + length);
      }
    }
  }
});

type.defineHooks({
  __getMountDeps: emptyFunction,
  __onMountFinish: function() {
    log.it(this.__name + ".isMounted = true");
    if (!(this._isConcealed || this.isConcealedByParent)) {
      this._reveal();
    }
  },
  __onReveal: function() {
    var childAbove;
    if (this._section) {
      childAbove = this._section.get(this._index - 1);
      if (childAbove) {
        if (childAbove.length === null) {
          return;
        }
        if (childAbove.isRevealed) {
          this._setOffset(childAbove.endOffset);
          return;
        }
      }
    }
    this._setOffset(0);
  },
  __onConceal: function() {
    this._isRevealed = false;
    this._inVisibleArea = null;
    this._setOffset(null);
  },
  __offsetDidChange: function(offset) {
    this._onLayout(offset, this._length);
  },
  __lengthDidChange: function(length) {
    this._onLayout(this._offset, length);
  },
  __sectionDidInsert: emptyFunction,
  __sectionWillRemove: function() {
    this._index = null;
    this._mounting = null;
    this._mountDeps = null;
    this._inVisibleArea = null;
    this._setOffset(null);
    this._setLength(null);
  }
});

module.exports = type.build();

//# sourceMappingURL=map/Child.map
