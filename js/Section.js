var Event, Promise, Random, Range, ReactiveList, ScrollChild, ScrollSection, SectionHeader, Style, Type, View, assertType, emptyFunction, ref, sync, type;

require("isDev");

ref = require("modx"), Type = ref.Type, Style = ref.Style;

View = require("modx/views").View;

emptyFunction = require("emptyFunction");

ReactiveList = require("ReactiveList");

assertType = require("assertType");

Promise = require("Promise");

Random = require("random");

Event = require("Event");

Range = require("Range");

sync = require("sync");

SectionHeader = require("./SectionHeader");

ScrollChild = require("./Child");

type = Type("Scrollable_Section");

type.inherits(ScrollChild);

type.defineOptions({
  mountedRange: Range,
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
    _mountedRange: options.mountedRange || [0, -1],
    _visibleRange: [],
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
  },
  mountedRange: {
    get: function() {
      return this._mountedRange;
    },
    set: function(range) {
      assertType(range, Range);
      this._mountedRange = range;
      return this.view && this._tryMounting();
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
    this._attachChild(child, index);
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
    this._detachChild(this._children.remove(index));
  },
  replaceAll: function(children) {
    var elements, oldChildren, section;
    assertType(children, Array);
    section = this;
    oldChildren = this._children._array;
    oldChildren && oldChildren.forEach(function(child) {
      return section._detachChild(child);
    });
    elements = new Array(children.length);
    children.forEach(function(child, index) {
      section._attachChild(child, index);
      return elements[index] = false;
    });
    this._visibleRange.length = 0;
    this._isRoot && this._scroll._setContentLength(null);
    this._children.array = children;
    this._childElements = elements;
  },
  forceUpdate: function(callback) {
    this.view && this.view.forceUpdate(callback);
  },
  mountAhead: function(distance) {
    var endIndex, ref1, startIndex;
    ref1 = this._mountedRange, startIndex = ref1[0], endIndex = ref1[1];
    if (distance > 0) {
      if (this._scroll.contentLength < (this._scroll.offset + this._scroll.visibleLength + distance)) {
        endIndex = Math.min(endIndex + this._batchSize, this._children._length._value);
        if (endIndex !== this._mountedRange[1]) {
          this._mountedRange = [startIndex, endIndex];
          return this._tryMounting();
        }
      }
    } else if (this._scroll.contentLength < (this._scroll.offset - distance)) {
      startIndex = Math.max(startIndex - this._batchSize, 0);
      if (startIndex !== this._mountedRange[0]) {
        this._mountedRange = [startIndex, endIndex];
        return this._tryMounting();
      }
    }
    return Promise(false);
  },
  updateVisibleRange: function() {
    var endOffset, startOffset;
    startOffset = this._scroll.offset;
    endOffset = startOffset + this._scroll.visibleLength;
    if (this._visibleRange.length) {
      this._updateVisibleRange(startOffset, endOffset);
    } else {
      this._initVisibleRange(startOffset, endOffset);
    }
    return this._visibleRange;
  },
  _attachChild: function(child, index) {
    if (child instanceof ScrollSection) {
      child._scroll = this._scroll;
    }
    child._index = index;
    child._section = this;
  },
  _detachChild: function(child) {
    if (child instanceof ScrollSection) {
      child._scroll = null;
    }
    child._index = null;
    child._section = null;
  },
  _prependChild: function(child) {
    assertType(child, ScrollChild.Kind);
    this._children.forEach(function(child) {
      return child._index += 1;
    });
    this._attachChild(child, 0);
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
      section._attachChild(child, index);
      return elements[index] = false;
    });
    this._children.prepend(children);
    this._childElements = elements.concat(this._childElements);
  },
  _appendChild: function(child) {
    assertType(child, ScrollChild.Kind);
    this._attachChild(child, this._children.length);
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
      section._attachChild(child, index + offset);
      return elements[index] = false;
    });
    this._children.append(children);
    this._childElements = this._childElements.concat(elements);
  },
  _tryMounting: function() {
    var onLayout, promise, ref1, resolve;
    ref1 = Promise.defer(), promise = ref1.promise, resolve = ref1.resolve;
    if (isDev && !this.view) {
      throw Error("Must be mounted before calling '_tryMounting'!");
    }
    onLayout = this.didLayout(1, resolve);
    onLayout.start();
    this.view.forceUpdate();
    return promise;
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
  }
});

type.overrideMethods({
  __onLengthChange: function(newValue, oldValue) {
    if (newValue === oldValue) {
      return;
    }
    if (this._isRoot) {
      this._scroll._setContentLength(newValue);
      return;
    }
    this._section._length += newValue - oldValue;
    this.didLayout.emit();
  }
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
    removeClippedSubviews: this.props.removeClippedSubviews
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
          return _this._headerLength = layout[_this._scroll.isHorizontal ? "width" : "height"];
        };
      })(this)
    });
  },
  _renderChildren: function() {
    var children, elements, endIndex, index, ref1, startIndex;
    ref1 = this._mountedRange, startIndex = ref1[0], endIndex = ref1[1];
    if (endIndex < 0) {
      return [];
    }
    children = this._children._array;
    elements = this._childElements;
    index = startIndex - 1;
    while (++index <= endIndex) {
      if (elements[index] !== false) {
        continue;
      }
      elements[index] = children[index].render();
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
          return _this._footerLength = layout[_this._scroll.isHorizontal ? "width" : "height"];
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
    return [this._renderHeader(), this._renderChildren(), this._renderFooter()];
  }
});

module.exports = ScrollSection = type.build();

//# sourceMappingURL=map/Section.map
