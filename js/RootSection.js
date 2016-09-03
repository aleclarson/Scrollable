var Section, Type, emptyFunction, type;

Type = require("modx").Type;

emptyFunction = require("emptyFunction");

Section = require("./Section");

type = Type("Scrollable_RootSection");

type.inherits(Section);

type.defineOptions({
  scroll: Object.Kind
});

type.defineValues(function(options) {
  return {
    _scroll: options.scroll
  };
});

type.initInstance(function() {
  this._index = 0;
  return this._trackMounting();
});

type.overrideMethods({
  __lengthDidChange: function(length) {
    this._scroll._setContentLength(length);
    this.__super(arguments);
  },
  __getVisibleArea: function() {
    var scroll;
    scroll = this._scroll;
    return {
      startOffset: scroll.offset,
      endOffset: scroll.offset + scroll.visibleLength
    };
  },
  __onRemoveAll: function() {
    this._scroll._setContentLength(null);
  },
  __renderEmpty: function() {
    return this._scroll.__renderEmpty();
  },
  __renderHeader: function() {
    return this._scroll.__renderHeader();
  },
  __renderFooter: function() {
    return this._scroll.__renderFooter();
  },
  __renderOverlay: function() {
    return this._scroll.__renderOverlay();
  },
  __childWillAttach: function(child, index) {
    return this._scroll.__childWillAttach(child, index);
  },
  __childDidAttach: function(child) {
    this._scroll.__childDidAttach(child);
  },
  __childWillDetach: function(child) {
    this._scroll.__childWillDetach(child);
  },
  __childDidLayout: function(child, lengthChange) {
    this._setLength(this._length + lengthChange);
    this._scroll.__childDidLayout(child, lengthChange);
  }
});

module.exports = type.build();

//# sourceMappingURL=map/RootSection.map
