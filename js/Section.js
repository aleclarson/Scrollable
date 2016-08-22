var Event, Promise, Random, ReactiveList, ScrollChild, ScrollSection, SectionHeader, Style, Type, View, assertType, emptyFunction, ref, sync, type;

require("isDev");

ref = require("modx"), Type = ref.Type, Style = ref.Style;

View = require("modx/views").View;

emptyFunction = require("emptyFunction");

ReactiveList = require("ReactiveList");

assertType = require("assertType");

Promise = require("Promise");

Random = require("random");

Event = require("Event");

sync = require("sync");

SectionHeader = require("./SectionHeader");

ScrollChild = require("./Child");

type = Type("Scrollable_Section");

type.inherits(ScrollChild);

type.defineOptions({
  startIndex: Number.withDefault(0),
  endIndex: Number.withDefault(0),
  batchSize: Number.withDefault(1),
  header: SectionHeader.Kind,
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
    _mountedRange: [options.startIndex, options.endIndex],
    _visibleRange: [],
    _rendering: null,
    _children: ReactiveList(),
    _childElements: [],
    _headerElement: false,
    _headerLength: null,
    _footerElement: false,
    _footerLength: null,
    _scroll: null
  };
});

type.defineGetters({
  array: function() {
    return this._children.array;
  },
  isEmpty: function() {
    return this._children.isEmpty;
  },
  visibleRange: function() {
    return this._visibleRange.slice();
  },
  scroll: function() {
    return this._scroll;
  },
  _isRoot: function() {
    return this === this._scroll._children;
  }
});

type.definePrototype({
  startIndex: {
    get: function() {
      return this._mountedRange[0];
    },
    set: function(index) {
      this._children._assertValidIndex(index);
      return this._mountedRange[0] = index;
    }
  },
  endIndex: {
    get: function() {
      return this._mountedRange[1];
    },
    set: function(index) {
      this._children._assertValidIndex(index);
      return this._mountedRange[1] = index;
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
    var children;
    assertType(index, Number);
    isDev && this._children._assertValidIndex(index);
    children = this._children._array;
    sync.repeat(numChildren - index, function(offset) {
      return children[index + offset]._index += 1;
    });
    assertType(child, ScrollChild.Kind);
    this._initChild(child, index);
    this._childElements.splice(index, 0, false);
    this._children.insert(index, child);
  },
  remove: function(index) {
    var children;
    assertType(index, Number);
    isDev && this._children._assertValidIndex(index);
    children = this._children._array;
    sync.repeat(this._children.length - index, function(offset) {
      return children[index + offset]._index -= 1;
    });
    this._childElements.splice(index, count);
    this._deinitChild(this._children.remove(index));
  },
  replaceAll: function(children) {
    var elements, oldChildren, section;
    assertType(children, Array);
    section = this;
    oldChildren = this._children._array;
    oldChildren && oldChildren.forEach(function(child) {
      return section._deinitChild(child);
    });
    elements = new Array(children.length);
    children.forEach(function(child, index) {
      section._initChild(child, index);
      return elements[index] = false;
    });
    this._visibleRange.length = 0;
    this._isRoot && this._scroll._setContentLength(null);
    this._children.array = children;
    this._childElements = elements;
  },
  updateRange: function(index, length) {
    assertType(index, Number);
    assertType(length, Number);
    this._mountedRange = [index, index + length];
    this.forceUpdate();
  },
  forceUpdate: function() {
    this.view && this.view.forceUpdate();
  },
  renderWhile: function(shouldRender) {
    var maxIndex;
    if (!shouldRender()) {
      return Promise();
    }
    maxIndex = this._children._length._value;
    if (this.endIndex === maxIndex) {
      return Promise();
    }
    return this._rendering != null ? this._rendering : this._rendering = Promise.defer((function(_this) {
      return function(resolve) {
        var onLayout;
        _this.endIndex = Math.max(_this.endIndex + _this._batchSize, maxIndex);
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
    if (this._visibleRange.length) {
      return this._updateVisibleRange(startOffset, endOffset);
    } else {
      return this._initVisibleRange(startOffset, endOffset);
    }
  },
  _initChild: function(child, index) {
    if (child instanceof ScrollSection) {
      child._scroll = this._scroll;
    }
    child._index = index;
    child._setSection(this);
  },
  _deinitChild: function(child) {
    if (child instanceof ScrollSection) {
      child._scroll = null;
    }
    child._index = null;
    child._setSection(null);
  },
  _prependChild: function(child) {
    assertType(child, ScrollChild.Kind);
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
      assertType(child, ScrollChild.Kind);
      section._initChild(child, index);
      return elements[index] = false;
    });
    this._children.prepend(children);
    this._childElements = elements.concat(this._childElements);
  },
  _appendChild: function(child) {
    assertType(child, ScrollChild.Kind);
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
      assertType(child, ScrollChild.Kind);
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
        if (_this.endIndex === _this._children.length) {
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
    if (!this._visibleRange.length) {
      return null;
    }
    return this._children.array.slice(this._visibleRange[0], this._visibleRange[1] + 1);
  },
  _initVisibleRange: function(startOffset, endOffset) {
    var beforeVisibleRange, child, children, elements, index, isHidden, lastVisibleIndex, numChildren;
    children = this._children._array;
    numChildren = this._children.length;
    beforeVisibleRange = true;
    lastVisibleIndex = null;
    elements = this._childElements;
    index = -1;
    while (++index < numChildren) {
      child = children[index];
      if (elements[index] === false) {
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
        this._visibleRange[0] = index;
      }
    }
    if (beforeVisibleRange) {
      this._visibleRange.length = 0;
      return;
    }
    this._visibleRange[1] = lastVisibleIndex;
  },
  _updateVisibleRange: function(startOffset, endOffset) {
    var child, children, index, startIndex;
    if (!this._visibleRange.length) {
      return this._initVisibleRange(startOffset, endOffset);
    }
    children = this._children._array;
    index = startIndex = this._visibleRange[0];
    while (child = children[index]) {
      if ((child.offset + child.length) > startOffset) {
        break;
      }
      this._visibleRange[0] = index;
      index += 1;
    }
    if (this._visibleRange[0] === startIndex) {
      index = startIndex - 1;
      while (child = children[index]) {
        if ((child.offset + child.length) < startOffset) {
          break;
        }
        this._visibleRange[0] = index;
        index -= 1;
      }
    }
    index = startIndex = this._visibleRange[1];
    while (child = children[index]) {
      if (child.offset < endOffset) {
        break;
      }
      this._visibleRange[1] = index;
      index -= 1;
    }
    if (this._visibleRange[1] === startIndex) {
      index = startIndex + 1;
      while (child = children[index]) {
        if (child.offset > endOffset) {
          break;
        }
        this._visibleRange[1] = index;
        index += 1;
      }
    }
  },
  _onLayout: function(layout) {
    var scroll;
    scroll = this.scroll;
    this._offset = layout[scroll.axis];
    this._length = layout[scroll.isHorizontal ? "width" : "height"];
    if (this._isRoot) {
      scroll._setContentLength(this._length);
    }
    return this.didLayout.emit();
  }
});

type.willUpdate(function() {
  return log.it(this.__name + ".willUpdate()");
});

type.defineProps({
  style: Style,
  removeClippedSubviews: Boolean.withDefault(false)
});

type.render(function() {
  var section;
  section = this.isEmpty ? this.__renderEmpty() : this.__renderSection();
  return View({
    style: this.props.style,
    children: section,
    removeClippedSubviews: this.props.removeClippedSubviews,
    onLayout: (function(_this) {
      return function(event) {
        return _this._onLayout(event.nativeEvent.layout);
      };
    })(this)
  });
});

type.defineMethods({
  _renderHeader: function() {
    if (this._headerElement !== false) {
      return this._headerElement;
    }
    return this._headerElement = View({
      children: this.__renderHeader(),
      onLayout: (function(_this) {
        return function(event) {
          var layout;
          layout = event.nativeEvent.layout;
          return _this._headerLength = layout[_this.scroll.isHorizontal ? "width" : "height"];
        };
      })(this)
    });
  },
  _renderChildren: function(startIndex, endIndex) {
    var children, elements, index, length, offset;
    length = endIndex - startIndex;
    children = this._children._array;
    elements = this._childElements;
    offset = -1;
    while (++offset < length) {
      index = startIndex + offset;
      if (elements[index] === false) {
        elements[index] = children[index].render();
      }
    }
    return elements;
  },
  _renderFooter: function() {
    if (this._footerElement !== false) {
      return this._footerElement;
    }
    return this._footerElement = View({
      children: this.__renderFooter(),
      onLayout: (function(_this) {
        return function(event) {
          var layout;
          layout = event.nativeEvent.layout;
          return _this._footerLength = layout[_this.scroll.isHorizontal ? "width" : "height"];
        };
      })(this)
    });
  }
});

type.defineHooks({
  __renderHeader: emptyFunction.thatReturnsFalse,
  __renderFooter: emptyFunction.thatReturnsFalse,
  __renderEmpty: emptyFunction.thatReturnsFalse,
  __renderSection: function() {
    return [this._renderHeader(), this._renderChildren(this.startIndex, this.endIndex), this._renderFooter()];
  }
});

module.exports = ScrollSection = type.build();

//# sourceMappingURL=map/Section.map
