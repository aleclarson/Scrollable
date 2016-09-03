var Event, Number, Promise, Range, ReactiveList, ReactiveRange, ScrollChild, ScrollSection, SectionHeader, Style, Type, View, assertType, emptyFunction, ref, sync, type;

require("isDev");

ref = require("modx"), Type = ref.Type, Style = ref.Style;

Number = require("Nan").Number;

View = require("modx/views").View;

emptyFunction = require("emptyFunction");

ReactiveRange = require("ReactiveRange");

ReactiveList = require("ReactiveList");

assertType = require("assertType");

Promise = require("Promise");

Event = require("Event");

Range = require("Range");

sync = require("sync");

SectionHeader = require("./SectionHeader");

ScrollChild = require("./Child");

type = Type("Scrollable_Section");

type.inherits(ScrollChild);

type.defineOptions({
  key: String,
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
    didLayout: Event(),
    _key: options.key,
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
    _elements: {
      header: false,
      children: [],
      footer: false,
      overlay: false
    },
    _visibleRange: [],
    _mountedRange: ReactiveRange(options.mountedRange || [0, -1]),
    _mountingRange: null
  };
});

type.defineListeners({
  _mountedRangeListener: function() {
    return this._mountedRange.didSet((function(_this) {
      return function(newRange, oldRange) {
        if (isDev) {
          if (newRange[0] < 0 || newRange[0] > _this._children.length - 1) {
            throw Error("Index out of range: " + newRange[0]);
          }
          if (newRange[1] < 0 || newRange[1] > _this._children.length - 1) {
            throw Error("Index out of range: " + newRange[1]);
          }
        }
        return _this._mountingRange = _this._trackMountingRange(newRange, oldRange);
      };
    })(this));
  }
});

type.defineGetters({
  array: function() {
    return this._children.array;
  },
  isEmpty: function() {
    return this._children.isEmpty;
  },
  visibleRange: function() {
    return this._visibleRange;
  },
  scroll: function() {
    return this._scroll;
  }
});

type.definePrototype({
  mountedRange: {
    get: function() {
      return this._mountedRange.get();
    },
    set: function(range) {
      return this._mountedRange.set(range);
    }
  }
});

type.defineBoundMethods({
  _headerDidLayout: function(event) {
    var layout, length, oldLength;
    layout = event.nativeEvent.layout;
    length = layout[this._scroll.isHorizontal ? "width" : "height"];
    if (length !== (oldLength = this._headerLength)) {
      this._headerLength = length;
      this._setLength(this._length + length - oldLength);
    }
  },
  _footerDidLayout: function(event) {
    var layout, length, oldLength;
    layout = event.nativeEvent.layout;
    length = layout[this._scroll.isHorizontal ? "width" : "height"];
    if (length !== (oldLength = this._footerLength)) {
      this._footerLength = length;
      this._setLength(this._length + length - oldLength);
    }
  }
});

type.defineMethods({
  inspect: function() {
    return {
      index: this.index,
      startOffset: this.startOffset,
      endOffset: this.endOffset,
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
  prepend: function(child) {
    this._children.forEach(function(child) {
      return child._index += 1;
    });
    child = this._attachChild(child, 0);
    assertType(child, ScrollChild.Kind);
    this._children.prepend(child);
    this._elements.children.unshift(false);
  },
  append: function(child) {
    child = this._attachChild(child, this._children.length);
    assertType(child, ScrollChild.Kind);
    this._children.append(child);
    this._elements.children.push(false);
  },
  insert: function(index, child) {
    var children;
    assertType(index, Number);
    isDev && this._children._assertValidIndex(index);
    children = this._children._array;
    sync.repeat(numChildren - index, function(offset) {
      return children[index + offset]._index += 1;
    });
    child = this._attachChild(child, index);
    assertType(child, ScrollChild.Kind);
    this._elements.children.splice(index, 0, false);
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
      log.it(this.__name + ".index = " + child._index);
      if (child.isRevealed && childAbove && childAbove.length !== null) {
        if (childAbove.isRevealed) {
          child._setOffset(childAbove.startOffset + childAbove.length);
        } else {
          child._setOffset(0);
        }
      }
      return childAbove = child;
    });
    this._elements.children.splice(index, count);
    this._children.remove(index);
  },
  removeAll: function() {
    if (this._children.length === 0) {
      return;
    }
    this._children.forEach((function(_this) {
      return function(child) {
        return _this._detachChild(child);
      };
    })(this));
    this._mountedRange.set([0, -1]);
    this._visibleRange.length = 0;
    this._children.length = 0;
    this._elements.children.length = 0;
  },
  mount: function(range) {
    assertType(range, Array.or(Function));
    if (Array.isArray(range)) {
      this._mountedRange.set(range);
    } else {
      range(this._mountedRange);
    }
    return this._mountingRange;
  },
  mountOffscreen: function(distance) {
    var endIndex, ref1, startIndex;
    ref1 = this._mountedRange.get(), startIndex = ref1[0], endIndex = ref1[1];
    if (distance > 0) {
      if (this._scroll.contentLength < this._scroll.offset + this._scroll.visibleLength + distance) {
        this._mountedRange.set([startIndex, endIndex + this._batchSize]);
        return this._mountingRange;
      }
    } else if (this._scroll.offset < 0 - distance) {
      this._mountedRange.set([startIndex - this._batchSize, endIndex]);
      return this._mountingRange;
    }
    return Promise();
  },
  forceUpdate: function(callback) {
    this.view && this.view.forceUpdate(callback);
  },
  _attachChild: function(child, index) {
    child = this.__childWillAttach(child, index);
    if (child instanceof ScrollSection) {
      child._scroll = this._scroll;
    }
    child._index = index;
    child._setSection(this);
    this.__childDidAttach(child);
    return child;
  },
  _detachChild: function(child) {
    this.__childWillDetach(child);
    child._setSection(null);
    if (child instanceof ScrollSection) {
      child._scroll = null;
    }
  },
  _trackMountingRange: function(newRange, oldRange) {
    var children, index, promises;
    children = this._children.array;
    promises = [];
    if (oldRange[0] - newRange[0] > 0) {
      index = oldRange[0];
      while (--index >= newRange[0]) {
        promises.push(children[index]._trackMounting());
      }
    }
    if (newRange[1] - oldRange[1] > 0) {
      index = oldRange[1];
      while (++index <= newRange[1]) {
        promises.push(children[index]._trackMounting());
      }
    }
    this.view && this.view.forceUpdate();
    if (promises.length) {
      return Promise.all(promises);
    }
    return Promise();
  },
  _revealMountedRange: function() {
    var child, children, endIndex, index, ref1, startIndex;
    ref1 = this._mountedRange.get(), startIndex = ref1[0], endIndex = ref1[1];
    children = this._children.array;
    index = startIndex - 1;
    while (++index <= endIndex) {
      child = children[index];
      if (!(child.isConcealed || child.isRevealed || !child.isMounted)) {
        child._reveal();
      }
    }
  },
  _getVisibleChildren: function() {
    if (!this._visibleRange.length) {
      return null;
    }
    return this._children.array.slice(this._visibleRange[0], this._visibleRange[1] + 1);
  },
  _isChildVisible: function(index) {
    if (!this._visibleRange.length) {
      return null;
    }
    if (index < this._visibleRange[0]) {
      return false;
    }
    return index <= this._visibleRange[1];
  },
  _updateVisibility: function() {
    var visibleArea;
    if (visibleArea = this.__getVisibleArea()) {
      this._inVisibleArea = true;
      if (this._visibleRange.length) {
        this._updateVisibleRange(visibleArea.startOffset, visibleArea.endOffset);
      } else {
        this._initVisibleRange(visibleArea.startOffset, visibleArea.endOffset);
      }
      return;
    }
    this._inVisibleArea = false;
    this._visibleRange = [-1, -1];
  },
  _initVisibleRange: function(startOffset, endOffset) {
    var beforeVisibleRange, child, children, elements, index, isHidden, lastVisibleIndex, numChildren;
    children = this._children._array;
    numChildren = this._children.length;
    beforeVisibleRange = true;
    lastVisibleIndex = null;
    elements = this._elements.children;
    index = -1;
    while (++index < numChildren) {
      child = children[index];
      if (elements[index] === false) {
        child._inVisibleArea = false;
        if (beforeVisibleRange) {
          continue;
        }
        break;
      }
      isHidden = beforeVisibleRange ? (child.startOffset + child.length) < startOffset : child.startOffset > endOffset;
      if (isHidden) {
        child._inVisibleArea = false;
        if (beforeVisibleRange) {
          continue;
        }
        break;
      }
      child._inVisibleArea = true;
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
      this._initVisibleRange(startOffset, endOffset);
      return;
    }
    children = this._children._array;
    index = startIndex = this._visibleRange[0];
    while (child = children[index]) {
      if ((child.startOffset + child.length) > startOffset) {
        break;
      }
      this._visibleRange[0] = index;
      index += 1;
    }
    if (this._visibleRange[0] === startIndex) {
      index = startIndex - 1;
      while (child = children[index]) {
        if ((child.startOffset + child.length) < startOffset) {
          break;
        }
        this._visibleRange[0] = index;
        index -= 1;
      }
    }
    index = startIndex = this._visibleRange[1];
    while (child = children[index]) {
      if (child.startOffset < endOffset) {
        break;
      }
      this._visibleRange[1] = index;
      index -= 1;
    }
    if (this._visibleRange[1] === startIndex) {
      index = startIndex + 1;
      while (child = children[index]) {
        if (child.startOffset > endOffset) {
          break;
        }
        this._visibleRange[1] = index;
        index += 1;
      }
    }
    log.it(this.__name + ".visibleRange = [ " + this._visibleRange.join(", ") + " ]");
  }
});

type.overrideMethods({
  __onReveal: function() {
    this.__super(arguments);
    if (this._section) {
      this._section.__childDidLayout(this, this._length);
    }
    this._updateVisibility();
    this._revealMountedRange();
  },
  __lengthDidChange: function(length, oldLength) {
    this.__super(arguments);
    if (this._isRevealed && this._section) {
      this._section.__childDidLayout(this, length - oldLength);
    }
    this.didLayout.emit();
  },
  __getMountDeps: function() {
    var children, endIndex, index, promises, ref1, startIndex;
    ref1 = this._mountedRange.get(), startIndex = ref1[0], endIndex = ref1[1];
    if (startIndex > endIndex) {
      return;
    }
    children = this._children.array;
    promises = [];
    index = startIndex - 1;
    while (++index <= endIndex) {
      promises.push(children[index]._trackMounting());
    }
    return Promise.all(promises);
  }
});

type.defineHooks({
  __getVisibleArea: function() {
    return this._scroll._isChildVisible(this);
  },
  __onRemoveAll: emptyFunction,
  __childWillAttach: emptyFunction.thatReturnsArgument,
  __childDidAttach: emptyFunction,
  __childWillDetach: emptyFunction,
  __childDidLayout: function(child, lengthChange) {
    this._setLength(this._length + lengthChange);
  }
});

type.defineProps({
  style: Style
});

type.render(function() {
  return View({
    key: this._key,
    ref: this._rootDidRef,
    style: [this.styles.container(), this.props.style, this._rootStyle],
    children: [this._renderHeader(), this.isEmpty ? this.__renderEmpty() : this._renderContents(), this._renderFooter(), this.__renderOverlay()]
  });
});

type.defineMethods({
  _renderHeader: function() {
    if (this._elements.header !== false) {
      return this._elements.header;
    }
    return this._elements.header = View({
      children: this.__renderHeader(),
      onLayout: this._headerDidLayout
    });
  },
  _renderContents: function() {
    var children, elements, endIndex, index, ref1, startIndex;
    ref1 = this._mountedRange.get(), startIndex = ref1[0], endIndex = ref1[1];
    if (endIndex < 0) {
      return [];
    }
    children = this._children._array;
    elements = this._elements.children;
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
    if (this._elements.footer !== false) {
      return this._elements.footer;
    }
    return this._elements.footer = View({
      children: this.__renderFooter(),
      onLayout: this._footerDidLayout
    });
  }
});

type.defineHooks({
  __renderEmpty: emptyFunction.thatReturnsFalse,
  __renderHeader: emptyFunction.thatReturnsFalse,
  __renderFooter: emptyFunction.thatReturnsFalse,
  __renderOverlay: emptyFunction.thatReturnsFalse
});

type.defineStyles({
  container: null,
  contents: null
});

module.exports = ScrollSection = type.build();

//# sourceMappingURL=map/Section.map
