var Event, Number, Promise, Random, Range, ReactiveList, ScrollChild, ScrollSection, SectionHeader, Style, Type, View, assertType, clampValue, emptyFunction, ref, sync, type;

require("isDev");

ref = require("modx"), Type = ref.Type, Style = ref.Style;

Number = require("Nan").Number;

View = require("modx/views").View;

emptyFunction = require("emptyFunction");

ReactiveList = require("ReactiveList");

assertType = require("assertType");

clampValue = require("clampValue");

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

type.defineReactiveValues({
  _headerLength: null,
  _footerLength: null,
  _scroll: null
});

type.defineValues(function(options) {
  return {
    _batchSize: options.batchSize,
    _children: ReactiveList(),
    _childElements: [],
    _headerElement: false,
    _footerElement: false,
    _visibleRange: [],
    _mountedRange: options.mountedRange || [0, -1],
    _mountingBehind: null,
    _mountingAhead: null
  };
});

type.defineGetters({
  array: function() {
    return this._children.array;
  },
  isEmpty: function() {
    return this._children.isEmpty;
  },
  startIndex: function() {
    return this._mountedRange[0];
  },
  endIndex: function() {
    return this._mountedRange[1];
  },
  mountedRange: function() {
    return this._mountedRange.slice();
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

type.defineMethods({
  inspect: function() {
    return {
      index: this.index,
      offset: this.offset,
      length: this.length,
      children: this._children.length,
      mountedRange: this.mountedRange,
      visibleRange: this.visibleRange
    };
  },
  get: function(index) {
    var child;
    if (Array.isArray(index)) {
      child = this._children.get(index.shift());
      if (index.length === 0) {
        return child;
      }
      if (!(child instanceof ScrollSection)) {
        return;
      }
      return child.get(index);
    }
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
    var childAbove, children;
    assertType(index, Number);
    isDev && this._children._assertValidIndex(index);
    children = this._children._array;
    this._detachChild(children[index]);
    childAbove = children[index - 1];
    sync.repeat(this._children.length - index, function(offset) {
      var child;
      child = children[index + offset];
      child._index -= 1;
      if (childAbove) {
        child._setOffset(childAbove.offset + childAbove.length);
      } else {
        child._setOffset(0);
      }
      return childAbove = child;
    });
    this._childElements.splice(index, count);
    this._children.remove(index);
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
  mount: function(arg) {
    assertType(arg, Array.or(Function));
    if (Array.isArray(arg)) {
      return this._setMountedRange(arg);
    }
    return Promise["try"]((function(_this) {
      return function() {
        var context, endIndex, ref1, startIndex;
        ref1 = _this._mountedRange, startIndex = ref1[0], endIndex = ref1[1];
        context = {
          startIndex: startIndex,
          endIndex: endIndex
        };
        arg.call(context);
        startIndex = context.startIndex, endIndex = context.endIndex;
        return _this._setMountedRange([startIndex, endIndex]);
      };
    })(this));
  },
  mountOffscreen: function(distance) {
    var endIndex, ref1, startIndex;
    ref1 = this._mountedRange, startIndex = ref1[0], endIndex = ref1[1];
    if (distance > 0) {
      if (this._scroll.contentLength < (this._scroll.offset + this._scroll.visibleLength + distance)) {
        return this._setMountedRange([startIndex, endIndex + this._batchSize]);
      }
    } else if (this._scroll.offset < 0 - distance) {
      return this._setMountedRange([startIndex - this._batchSize, endIndex]);
    }
    return Promise();
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
    child._setSection(this);
  },
  _detachChild: function(child) {
    child._setSection(null);
    if (child instanceof ScrollSection) {
      child._scroll = null;
    }
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
  _setMountedRange: function(newRange) {
    var children, endIndex, index, maxIndex, oldRange, promise, promises, startIndex;
    oldRange = this._mountedRange;
    children = this._children.array;
    maxIndex = this._children.length - 1;
    startIndex = clampValue(newRange[0], 0, maxIndex);
    endIndex = clampValue(newRange[1], 0, maxIndex);
    if (startIndex === oldRange[0]) {
      if (endIndex === oldRange[1]) {
        return Promise();
      }
    }
    log.it(this.__name + (".mountedRange = [" + startIndex + ", " + endIndex + "]"));
    this._mountedRange = [startIndex, endIndex];
    promises = [];
    if (oldRange[0] - startIndex > 0) {
      index = oldRange[0];
      while (--index >= startIndex) {
        promise = children[index]._mountWillBegin();
        promises.push(promise);
      }
    }
    if (endIndex - oldRange[1] > 0) {
      index = oldRange[1];
      while (++index <= endIndex) {
        promise = children[index]._mountWillBegin();
        promises.push(promise);
      }
    }
    this.view && this.view.forceUpdate();
    if (!promises.length) {
      return Promise();
    }
    if (this._mounting !== null) {
      return Promise.all(promises);
    }
    this._mountWillBegin();
    return Promise.all(promises).then((function(_this) {
      return function() {
        return _this._mountDidFinish();
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
  _childDidLayout: function(child, lengthChange) {
    this._setLength(this._length + lengthChange);
    this._isRoot && this._scroll._childDidLayout(child, lengthChange);
  }
});

type.overrideMethods({
  __lengthDidChange: function(length, oldLength) {
    if (this._offset === null && length !== null) {
      if (this._isRoot || this.isFirst) {
        this._offset = 0;
      }
    }
    this.__super(arguments);
    if (this._isRoot) {
      this._scroll._setContentLength(length);
    } else {
      this._section._childDidLayout(this, length - oldLength);
    }
    this.didLayout.emit();
  },
  __mountWillBegin: function() {
    var children, endIndex, index, ref1, startIndex;
    ref1 = this._mountedRange, startIndex = ref1[0], endIndex = ref1[1];
    if (startIndex > endIndex) {
      return;
    }
    children = this._children.array;
    index = startIndex - 1;
    while (++index <= endIndex) {
      children[index]._mountWillBegin();
    }
  },
  __mountWillFinish: function() {
    var children, endIndex, index, promises, ref1, startIndex;
    ref1 = this._mountedRange, startIndex = ref1[0], endIndex = ref1[1];
    if (startIndex > endIndex) {
      return;
    }
    promises = [];
    children = this._children.array;
    index = startIndex - 1;
    while (++index <= endIndex) {
      promises.push(children[index]._mounting);
    }
    return Promise.all(promises);
  }
});

type.defineProps({
  style: Style,
  removeClippedSubviews: Boolean.withDefault(false)
});

type.render(function() {
  return View({
    removeClippedSubviews: this.props.removeClippedSubviews,
    style: [this.styles.container(), this.props.style],
    children: [this._renderHeader(), this.isEmpty ? this.__renderEmpty() : this._renderContents(), this._renderFooter()]
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
          var layout, oldLength;
          layout = event.nativeEvent.layout;
          oldLength = _this._headerLength;
          _this._headerLength = layout[_this._scroll.isHorizontal ? "width" : "height"];
          return _this._setLength(_this._length + _this._headerLength - oldLength);
        };
      })(this)
    });
  },
  _renderContents: function() {
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
    return View({
      style: this.styles.contents(),
      children: elements
    });
  },
  _renderFooter: function() {
    if (this._footerElement !== false) {
      return this._footerElement;
    }
    return this._footerElement = View({
      children: this.__renderFooter(),
      onLayout: (function(_this) {
        return function(event) {
          var layout, oldLength;
          layout = event.nativeEvent.layout;
          oldLength = _this._footerLength;
          _this._footerLength = layout[_this._scroll.isHorizontal ? "width" : "height"];
          return _this._setLength(_this._length + _this._footerLength - oldLength);
        };
      })(this)
    });
  }
});

type.defineHooks({
  __renderHeader: emptyFunction.thatReturnsFalse,
  __renderFooter: emptyFunction.thatReturnsFalse,
  __renderEmpty: emptyFunction.thatReturnsFalse
});

type.defineStyles({
  container: null,
  contents: null
});

module.exports = ScrollSection = type.build();

//# sourceMappingURL=map/Section.map
