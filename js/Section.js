var Event, LazyVar, Promise, Random, ScrollChild, ScrollSection, SectionHeader, Style, Type, View, assert, assertType, clampValue, emptyFunction, fromArgs, ref, sync, type;

require("isDev");

ref = require("modx"), Type = ref.Type, Style = ref.Style;

View = require("modx/views").View;

emptyFunction = require("emptyFunction");

assertType = require("assertType");

clampValue = require("clampValue");

fromArgs = require("fromArgs");

LazyVar = require("LazyVar");

Promise = require("Promise");

Random = require("random");

assert = require("assert");

Event = require("Event");

sync = require("sync");

SectionHeader = require("./SectionHeader");

ScrollChild = LazyVar(function() {
  return require("./Child");
});

type = Type("Scrollable_Section");

type.defineOptions({
  startIndex: Number.withDefault(0),
  endIndex: Number.withDefault(0),
  batchSize: Number.withDefault(1),
  header: ScrollHeader.Kind,
  renderHeader: Function,
  renderFooter: Function,
  renderEmpty: Function
});

type.defineStatics({
  Header: {
    get: function() {
      return SectionHeader;
    }
  }
});

type.defineFrozenValues(function(options) {
  return {
    key: Random.id(8),
    didLayout: Event(),
    _header: options.header,
    __renderHeader: options.renderHeader,
    __renderFooter: options.renderFooter,
    __renderEmpty: options.renderEmpty
  };
});

type.defineValues(function(options) {
  return {
    _batchSize: options.batchSize,
    _startIndex: options.startIndex,
    _endIndex: options.endIndex,
    _rendering: null,
    _children: ReactiveList(),
    _childElements: [],
    _headerElements: [],
    _footerElement: null,
    _footerLength: null,
    _section: null,
    _scroll: null
  };
});

type.defineReactiveValues(function() {
  return {
    _index: null,
    _offset: null,
    _length: null,
    _firstVisibleIndex: null,
    _lastVisibleIndex: null
  };
});

type.defineGetters({
  isEmpty: function() {
    return this._children.isEmpty;
  },
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
  firstVisibleIndex: function() {
    return this._firstVisibleIndex;
  },
  lastVisibleIndex: function() {
    return this._lastVisibleIndex;
  },
  section: function() {
    return this._section;
  },
  scroll: function() {
    return this._scroll;
  },
  _isRoot: function() {
    return this === this._scroll._section;
  }
});

type.definePrototype({
  children: {
    get: function() {
      return this._children.array;
    },
    set: function(children) {
      var elements, length, section;
      assertType(children, Array);
      length = children.length;
      elements = new Array(length);
      if (length) {
        section = this;
        children.forEach(function(child, index) {
          section._initChild(child, index);
          return elements[index] = false;
        });
      }
      this._firstVisibleIndex = null;
      this._lastVisibleIndex = null;
      this._isRoot && this._scroll._setContentLength(null);
      this._children.array = children;
      this._childElements = elements;
    }
  },
  startIndex: {
    get: function() {
      return this._startIndex;
    },
    set: function(newValue) {
      return this._startIndex = clampValue(newValue, 0, this._children.length);
    }
  },
  endIndex: {
    get: function() {
      return this._endIndex;
    },
    set: function(newValue) {
      return this._endIndex = clampValue(newValue, 0, this._children.length);
    }
  }
});

type.defineMethods({
  get: function(index) {
    return this._children.get(index);
  },
  prepend: function(children) {
    if (Array.isArray(children)) {
      return this._prependChildren(children);
    } else {
      return this._prependChild(children);
    }
  },
  append: function(children) {
    if (Array.isArray(children)) {
      return this._appendChildren(children);
    } else {
      return this._appendChild(children);
    }
  },
  insert: function(index, child) {
    var children, length;
    assertType(index, Number);
    assert(index >= 0 && index < this._children.length, {
      index: index,
      reason: "'index' out of bounds!"
    });
    length = (children = this._children).length;
    sync.repeat(length - index, function(offset) {
      return children[index + offset]._index += 1;
    });
    assertType(child, ScrollChild.get());
    this._initChild(child, index);
    children.splice(index, 0, child);
    this._childElements.splice(index, 0, false);
  },
  remove: function(index, count) {
    var children, length, startIndex;
    assertType(index, Number);
    assertType(count, Number);
    if (count <= 0) {
      return;
    }
    length = (children = this._children).length;
    startIndex = Math.min(index + count, length);
    sync.repeat(length - startIndex, function(offset) {
      return children[startIndex + offset]._index -= 1;
    });
    children.splice(index, count);
    this._childElements.splice(index, count);
  },
  forceUpdate: function() {
    this.view && this.view.forceUpdate();
  },
  renderWhile: function(shouldRender) {
    if (!shouldRender()) {
      return Promise();
    }
    return this._rendering != null ? this._rendering : this._rendering = Promise.defer((function(_this) {
      return function(resolve) {
        var onLayout;
        _this.endIndex += _this.batchSize;
        onLayout = _this.didLayout(1, function() {
          return _this.renderWhile(shouldRender).then(resolve);
        });
        onLayout.start();
        return _this.forceUpdate();
      };
    })(this));
  },
  renderWhileVisible: function() {
    var onLayout;
    if (this._scroll.maxOffset !== null) {
      this._renderWhileVisible();
      return;
    }
    onLayout = this._scroll.didLayout(1, (function(_this) {
      return function() {
        return _this._renderWhileVisible();
      };
    })(this)).start();
  },
  updateVisibleRange: function() {
    var endOffset, startOffset;
    startOffset = this._scroll.offset;
    endOffset = startOffset + this._scroll.visibleLength;
    if (this._firstVisibleIndex === null) {
      return this._initVisibleRange(startOffset, endOffset);
    } else {
      return this._updateVisibleRange(startOffset, endOffset);
    }
  },
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
  },
  _initChild: function(child, index) {
    child._index = index;
    child._section = this;
    if (child instanceof ScrollSection) {
      child._scroll = this._scroll;
    }
  },
  _prependChild: function(child) {
    assertType(child, ScrollChild.get());
    this._children.forEach(function(child) {
      return child._index += 1;
    });
    this._initChild(child, 0);
    this._children.prepend(child);
    this._childElements.unshift(false);
  },
  _prependChildren: function(children) {
    var elements, length, section;
    if (!(length = children.length)) {
      return;
    }
    this._children.forEach(function(child) {
      return child._index += length;
    });
    section = this;
    elements = new Array(length);
    children.forEach(function(child, index) {
      assertType(child, ScrollChild.get());
      section._initChild(child, index);
      return elements[index] = false;
    });
    this._children.prepend(children);
    this._childElements = elements.concat(this._childElements);
  },
  _appendChild: function(child) {
    assertType(child, ScrollChild.get());
    this._initChild(child, this._children.length);
    this._children.append(child);
    this._childElements.push(false);
  },
  _appendChildren: function(children) {
    var elements, length, offset, section;
    if (!(length = children.length)) {
      return;
    }
    offset = this._children.length;
    section = this;
    elements = new Array(length);
    children.forEach(function(child, index) {
      assertType(child, ScrollChild.get());
      section._initChild(child, index + offset);
      return elements[index] = false;
    });
    this._children.append(children);
    this._childElements = this._childElements.concat(elements);
  },
  _renderWhileVisible: function() {
    var scroll;
    scroll = this._scroll;
    return this.renderWhile((function(_this) {
      return function() {
        var endLength;
        if (_this._endIndex === _this._children.length) {
          return false;
        }
        endLength = scroll.offset + scroll.visibleLength + scroll.visibleThreshold;
        return scroll.contentLength < endLength;
      };
    })(this));
  },
  _isAreaVisible: function(offset, length) {
    var endOffset, startOffset;
    if (this._scroll.visibleLength === null) {
      return null;
    }
    startOffset = this.offset;
    endOffset = top + this._scroll.visibleLength;
    if (offset < endOffset) {
      return true;
    }
    return offset + length > startOffset;
  },
  _getVisibleChildren: function() {
    if (this._firstVisibleIndex === null) {
      return null;
    }
    return this._children.array.slice(this._firstVisibleIndex, this._lastVisibleIndex + 1);
  },
  _initVisibleRange: function(startOffset, endOffset) {
    var beforeVisibleRange, child, children, elements, index, isHidden, lastVisibleIndex, numChildren;
    children = this._children._array;
    numChildren = this._children._length;
    beforeVisibleRange = true;
    lastVisibleIndex = null;
    elements = this._childElements;
    index = -1;
    while (++index < numChildren) {
      child = children[index];
      if (element === false) {
        child._isVisible = false;
        if (beforeVisibleRange) {
          continue;
        }
        break;
      }
      isHidden = beforeVisibleRange ? (child.offset + child.length) < startOffset : child.offset > endOffset;
      if (isHidden) {
        child._isVisible = false;
        if (beforeVisibleRange) {
          continue;
        }
        break;
      }
      child._isVisible = true;
      lastVisibleIndex = index;
      if (beforeVisibleRange) {
        beforeVisibleRange = false;
        this._firstVisibleIndex = index;
      }
    }
    if (beforeVisibleRange) {
      this._firstVisibleIndex = null;
    }
    this._lastVisibleIndex = lastVisibleIndex;
  },
  _updateVisibleRange: function(startOffset, endOffset) {
    var child, children, index, startIndex;
    if (this._firstVisibleIndex === null) {
      return this._initVisibleRange(startOffset, endOffset);
    }
    children = this._children._array;
    index = startIndex = this._firstVisibleIndex;
    while (child = children[index]) {
      if ((child.offset + child.length) > startOffset) {
        break;
      }
      this._firstVisibleIndex = index;
      index += 1;
    }
    if (this._firstVisibleIndex === startIndex) {
      index = this._firstVisibleIndex - 1;
      while (child = children[index]) {
        if ((child.offset + child.length) < startOffset) {
          break;
        }
        this._firstVisibleIndex = index;
        index -= 1;
      }
    }
    index = startIndex = this._lastVisibleIndex;
    while (child = children[index]) {
      if (child.offset < endOffset) {
        break;
      }
      this._lastVisibleIndex = index;
      index -= 1;
    }
    if (this._lastVisibleIndex === startIndex) {
      index = this._lastVisibleIndex + 1;
      while (child = children[index]) {
        if (child.offset > endOffset) {
          break;
        }
        this._lastVisibleIndex = index;
        index += 1;
      }
    }
  },
  _onLayout: function(layout) {
    var scroll;
    scroll = this.scroll;
    this._offset = layout[scroll.axis];
    this._length = layout[scroll.axis === "x" ? "width" : "height"];
    if (this._isRoot) {
      scroll._setContentLength(this._length);
    } else {
      this._isVisible = scroll._isAreaVisible(this._offset, this._length);
    }
    return this.didLayout.emit();
  },
  _onFooterLayout: function(layout) {
    return this._footerLength = layout[this.scroll.axis === "x" ? "width" : "height"];
  }
});

type.defineHooks({
  __onInsert: emptyFunction,
  __onRemove: emptyFunction
});

type.propTypes = {
  style: Style,
  removeClippedSubviews: Boolean
};

type.propDefaults = {
  removeClippedSubviews: false
};

type.render(function() {
  return View({
    style: this.props.style,
    children: this._renderSection(),
    removeClippedSubviews: this.props.removeClippedSubviews,
    onLayout: (function(_this) {
      return function(event) {
        return _this._onLayout(event.nativeEvent.layout);
      };
    })(this)
  });
});

type.defineMethods({
  _renderSection: function() {
    var base, base1, children, length;
    if (this.isEmpty) {
      return this.__renderEmpty();
    }
    length = (children = this._renderChildren()).length;
    if ((base = this._headerElements)[0] == null) {
      base[0] = this._header ? this._header.renderEmpty() : this.__renderHeader();
    }
    if ((base1 = this._headerElements)[1] == null) {
      base1[1] = this._header ? this._header.render() : false;
    }
    if (this._children.length === length) {
      if (this._footerElement == null) {
        this._footerElement = View({
          children: this.__renderFooter(),
          onLayout: (function(_this) {
            return function(event) {
              return _this._onFooterLayout(event.nativeEvent.layout);
            };
          })(this)
        });
      }
    }
    return [this._headerElements[0], children, this._headerElements[1], this._footerElement];
  },
  _renderChildren: function() {
    var children, elements, endIndex, index, length, offset, ref1, startIndex;
    ref1 = this, startIndex = ref1.startIndex, endIndex = ref1.endIndex;
    length = endIndex - startIndex;
    children = this._children;
    elements = this._childElements;
    offset = -1;
    while (++offset < length) {
      index = startIndex + offset;
      if (elements[index] !== false) {
        continue;
      }
      elements[index] = children[index].render();
    }
    return elements;
  }
});

type.defineHooks({
  __renderHeader: emptyFunction.thatReturnsFalse,
  __renderFooter: emptyFunction.thatReturnsFalse,
  __renderEmpty: emptyFunction.thatReturnsFalse
});

module.exports = ScrollSection = type.build();

//# sourceMappingURL=map/Section.map
