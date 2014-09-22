var MentionsBase, MentionsContenteditable, MentionsInput, Selection, namespace, settings,
  __bind = function(fn, me){ return function(){ return fn.apply(me, arguments); }; },
  __hasProp = {}.hasOwnProperty,
  __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; },
  __slice = [].slice;

namespace = "mentionsInput";

Selection = {
  get: function(input) {
    return {
      start: input[0].selectionStart,
      end: input[0].selectionEnd
    };
  },
  set: function(input, start, end) {
    if (end == null) {
      end = start;
    }
    if (input[0].selectionStart) {
      input[0].selectStart = start;
      return input[0].selectionEnd = end;
    }
  }
};

settings = {
  delay: 0,
  trigger: '@'
};

$.widget("ui.areacomplete", $.ui.autocomplete, {
  options: $.extend({}, $.ui.autocomplete.prototype.options, {
    matcher: "(\\b[^,]*)",
    suffix: ', '
  }),
  _create: function() {
    this.overriden = {
      select: this.options.select,
      focus: this.options.focus
    };
    this.options.select = $.proxy(this.selectCallback, this);
    this.options.focus = $.proxy(this.focusCallback, this);
    $.ui.autocomplete.prototype._create.call(this);
    return this.matcher = new RegExp(this.options.matcher + '$');
  },
  selectCallback: function(event, ui) {
    var after, before, newval, value;
    value = this._value();
    before = value.substring(0, this.start);
    after = value.substring(this.end);
    newval = ui.item.value + this.options.suffix;
    value = before + newval + after;
    if (this.overriden.select) {
      ui.item.pos = this.start;
      if (this.overriden.select(event, ui) === false) {
        return false;
      }
    }
    this._value(value);
    this.element.change();
    Selection.set(this.element, before.length + newval.length);
    return false;
  },
  focusCallback: function() {
    if (this.overriden.focus) {
      return this.overriden.focus(event, ui);
    }
    return false;
  },
  search: function(value, event) {
    var match, pos;
    if (!value) {
      value = this._value();
      pos = Selection.get(this.element).start;
      value = value.substring(0, pos);
      match = this.matcher.exec(value);
      if (!match) {
        return '';
      }
      this.start = match.index;
      this.end = match.index + match[0].length;
      value = match[1];
    }
    return $.ui.autocomplete.prototype.search.call(this, value, event);
  },
  _renderItem: function(ul, item) {
    var anchor, li;
    li = $('<li>');
    anchor = $('<a>').appendTo(li);
    if (item.image) {
      anchor.append("<img src=\"" + item.image + "\" />");
    }
    anchor.append(item.value);
    return li.appendTo(ul);
  }
});

$.widget("ui.editablecomplete", $.ui.areacomplete, {
  options: $.extend({}, $.ui.areacomplete.prototype.options, {
    showAtCaret: false
  }),
  selectCallback: function(event, ui) {
    var mention, pos;
    pos = {
      start: this.start,
      end: this.end
    };
    if (this.overriden.select) {
      ui.item.pos = pos;
      if (this.overriden.select(event, ui) === false) {
        return false;
      }
    }
    mention = document.createTextNode(ui.item.value);
    insertMention(mention, pos, this.options.suffix);
    this.element.change();
    return false;
  },
  search: function(value, event) {
    var match, node, pos, sel;
    if (!value) {
      sel = window.getSelection();
      node = sel.focusNode;
      value = node.textContent;
      pos = sel.focusOffset;
      value = value.substring(0, pos);
      match = this.matcher.exec(value);
      if (!match) {
        return '';
      }
      this.start = match.index;
      this.end = match.index + match[0].length;
      this._setDropdownPosition(node);
      value = match[1];
    }
    return $.ui.autocomplete.prototype.search.call(this, value, event);
  },
  _setDropdownPosition: function(node) {
    var boundary, posX, posY, rect;
    if (this.options.showAtCaret) {
      boundary = document.createRange();
      boundary.setStart(node, this.start);
      boundary.collapse(true);
      rect = boundary.getClientRects()[0];
      posX = rect.left + (window.scrollX || window.pageXOffset);
      posY = rect.top + rect.height + (window.scrollY || window.pageYOffset);
      this.options.position.of = document;
      return this.options.position.at = "left+" + posX + " top+" + posY;
    }
  }
});

MentionsBase = (function() {
  MentionsBase.prototype.marker = '\uFEFF';

  function MentionsBase(input, options) {
    this.input = input;
    this.options = $.extend({}, settings, options);
    if (!this.options.source) {
      this.options.source = this.input.data('source') || [];
    }
  }

  MentionsBase.prototype._getMatcher = function() {
    var allowedChars;
    allowedChars = '[^' + this.options.trigger + ']';
    return '\\B[' + this.options.trigger + '](' + allowedChars + '{0,20})';
  };

  return MentionsBase;

})();

MentionsInput = (function(_super) {
  var Key, mimicProperties;

  __extends(MentionsInput, _super);

  Key = {
    LEFT: 37,
    RIGHT: 39
  };

  mimicProperties = ['marginTop', 'marginBottom', 'marginLeft', 'marginRight', 'paddingTop', 'paddingBottom', 'paddingLeft', 'paddingRight', 'borderTopWidth', 'borderLeftWidth', 'borderBottomWidth', 'borderRightWidth', 'fontSize', 'fontStyle', 'fontFamily', 'fontWeight', 'lineHeight', 'height', 'boxSizing'];

  function MentionsInput(input, options) {
    var container;
    this.input = input;
    this._updateHScroll = __bind(this._updateHScroll, this);
    this._updateVScroll = __bind(this._updateVScroll, this);
    this._updateValue = __bind(this._updateValue, this);
    this._onSelect = __bind(this._onSelect, this);
    this._addMention = __bind(this._addMention, this);
    this._updateMentions = __bind(this._updateMentions, this);
    this._update = __bind(this._update, this);
    this._mark = __bind(this._mark, this);
    this._handleLeftRight = __bind(this._handleLeftRight, this);
    this._setHighligherStyle = __bind(this._setHighligherStyle, this);
    MentionsInput.__super__.constructor.call(this, this.input, options);
    this.mentions = [];
    this.input.addClass('input');
    container = $('<div>', {
      'class': 'mentions-input'
    });
    container.css('display', this.input.css('display'));
    this.container = this.input.wrapAll(container).parent();
    this.hidden = this._createHidden();
    this.highlighter = this._createHighlighter();
    this._setHighligherStyle();
    this.highlighterContent = $('div', this.highlighter);
    this.input.focus((function(_this) {
      return function() {
        return _this.highlighter.addClass('focus');
      };
    })(this)).blur((function(_this) {
      return function() {
        return _this.highlighter.removeClass('focus');
      };
    })(this));
    this.autocomplete = this.input.areacomplete({
      matcher: this._getMatcher(),
      suffix: this.marker,
      select: this._onSelect,
      source: this.options.source,
      delay: this.options.delay,
      appendTo: this.input.parent()
    });
    this._initValue();
    this._initEvents();
  }

  MentionsInput.prototype._initEvents = function() {
    var tagName;
    this.input.on("input." + namespace + " change." + namespace, this._update);
    this.input.on("keydown." + namespace, (function(_this) {
      return function(event) {
        return setTimeout((function() {
          return _this._handleLeftRight(event);
        }), 10);
      };
    })(this));
    tagName = this.input.prop("tagName");
    if (tagName === "INPUT") {
      this.input.on("focus." + namespace, (function(_this) {
        return function() {
          return _this.interval = setInterval(_this._updateHScroll, 10);
        };
      })(this));
      this.input.on("blur." + namespace, (function(_this) {
        return function() {
          setTimeout(_this._updateHScroll, 10);
          return clearInterval(_this.interval);
        };
      })(this));
    } else if (tagName === "TEXTAREA") {
      this.input.on("scroll." + namespace, ((function(_this) {
        return function() {
          return setTimeout(_this._updateVScroll, 10);
        };
      })(this)));
      this.input.on("resize." + namespace, ((function(_this) {
        return function() {
          return setTimeout(_this._updateVScroll, 10);
        };
      })(this)));
    }
    $(window).on("load", this._setHighligherStyle);
    return this.input.on("focus." + namespace + " blur." + namespace, this._setHighligherStyle);
  };

  MentionsInput.prototype._initValue = function() {
    return this._setValue(this.input.val());
  };

  MentionsInput.prototype._setValue = function(value) {
    var markedValue, match, mentionRE, pos;
    mentionRE = /@\[([^\]]+)\]\(([^ \)]+)\)/g;
    markedValue = value.replace(mentionRE, this._mark('$1'));
    this.input.val(markedValue);
    match = mentionRE.exec(value);
    while (match) {
      this._addMention({
        name: match[1],
        uid: match[2]
      }, pos = markedValue.indexOf(this._mark(match[1])));
      match = mentionRE.exec(value);
    }
    return this._updateValue();
  };

  MentionsInput.prototype._createHidden = function() {
    var hidden;
    hidden = $('<input>', {
      type: 'hidden',
      name: this.input.attr('name')
    });
    hidden.appendTo(this.container);
    this.input.removeAttr('name');
    return hidden;
  };

  MentionsInput.prototype._createHighlighter = function() {
    var content, highlighter;
    highlighter = $('<div>', {
      'class': 'highlighter'
    });
    content = $('<div>', {
      'class': 'highlighter-content'
    });
    highlighter.append(content).prependTo(this.container);
    this.input.css('backgroundColor', 'transparent');
    return highlighter;
  };

  MentionsInput.prototype._setHighligherStyle = function() {
    var property, _i, _len, _results;
    _results = [];
    for (_i = 0, _len = mimicProperties.length; _i < _len; _i++) {
      property = mimicProperties[_i];
      _results.push(this.highlighter.css(property, this.input.css(property)));
    }
    return _results;
  };

  MentionsInput.prototype._handleLeftRight = function(event) {
    var delta, deltaEnd, deltaStart, sel, value;
    if (event.keyCode === Key.LEFT || event.keyCode === Key.RIGHT) {
      value = this.input.val();
      sel = Selection.get(this.input);
      delta = event.keyCode === Key.LEFT ? -1 : 1;
      deltaStart = value.charAt(sel.start) === this.marker ? delta : 0;
      deltaEnd = value.charAt(sel.end) === this.marker ? delta : 0;
      if (deltaStart || deltaEnd) {
        return Selection.set(this.input, sel.start + deltaStart, sel.end + deltaEnd);
      }
    }
  };

  MentionsInput.prototype._mark = function(name) {
    return name + this.marker;
  };

  MentionsInput.prototype._update = function() {
    this._updateMentions();
    return this._updateValue();
  };

  MentionsInput.prototype._updateMentions = function() {
    var i, index, marked, mention, newval, selection, value, _i, _len, _ref;
    value = this.input.val();
    if (value) {
      _ref = this.mentions.slice(0);
      for (i = _i = 0, _len = _ref.length; _i < _len; i = ++_i) {
        mention = _ref[i];
        marked = this._mark(mention.name);
        index = value.indexOf(marked);
        if (index === -1) {
          this.mentions.splice(i, 1);
        } else {
          mention.pos = index;
        }
        value = this._replaceWithSpaces(value, marked);
      }
      newval = this.input.val();
      while ((index = value.indexOf(this.marker)) >= 0) {
        value = this._cutChar(value, index);
        newval = this._cutChar(newval, index);
      }
      if (value !== newval) {
        selection = Selection.get(this.input);
        this.input.val(newval);
        return Selection.set(this.input, selection.start);
      }
    }
  };

  MentionsInput.prototype._addMention = function(mention) {
    return this.mentions.push(mention);
  };

  MentionsInput.prototype._onSelect = function(event, ui) {
    return this._addMention({
      name: ui.item.value,
      pos: ui.item.pos,
      uid: ui.item.uid
    });
  };

  MentionsInput.prototype._updateValue = function() {
    var hlContent, markedName, mention, value, _i, _len, _ref;
    value = hlContent = this.input.val();
    _ref = this.mentions;
    for (_i = 0, _len = _ref.length; _i < _len; _i++) {
      mention = _ref[_i];
      markedName = this._mark(mention.name);
      hlContent = hlContent.replace(markedName, "<strong>" + mention.name + "</strong>");
      value = value.replace(markedName, "@[" + mention.name + "](" + mention.uid + ")");
    }
    this.hidden.val(value);
    return this.highlighterContent.html(hlContent);
  };

  MentionsInput.prototype._updateVScroll = function() {
    var scrollTop;
    scrollTop = this.input.scrollTop();
    this.highlighterContent.css({
      top: "-" + scrollTop + "px"
    });
    return this.highlighter.height(this.input.height());
  };

  MentionsInput.prototype._updateHScroll = function() {
    var scrollLeft;
    scrollLeft = this.input.scrollLeft();
    this.highlighterContent.css({
      left: "-" + scrollLeft + "px"
    });
    return this.highlighterContent.width(this.input.get(0).scrollWidth);
  };

  MentionsInput.prototype._replaceWithSpaces = function(value, what) {
    return value.replace(what, Array(what.length).join(' '));
  };

  MentionsInput.prototype._cutChar = function(value, index) {
    return value.substring(0, index) + value.substring(index + 1);
  };

  MentionsInput.prototype.append = function() {
    var piece, pieces, value, _i, _len;
    pieces = 1 <= arguments.length ? __slice.call(arguments, 0) : [];
    value = this.input.val();
    for (_i = 0, _len = pieces.length; _i < _len; _i++) {
      piece = pieces[_i];
      if (typeof piece === 'string') {
        value += piece;
      } else {
        this._addMention({
          name: piece.name,
          uid: piece.uid,
          pos: value.length
        });
        value += this._mark(piece.name);
      }
    }
    this.input.val(value);
    return this._updateValue();
  };

  MentionsInput.prototype.setValue = function(value) {
    this._setValue(value);
    return this._initEvents();
  };

  MentionsInput.prototype.getValue = function() {
    return this.hidden.val();
  };

  MentionsInput.prototype.clear = function() {
    this.input.val('');
    return this._update();
  };

  MentionsInput.prototype.destroy = function() {
    this.input.areacomplete("destroy");
    this.input.off("." + namespace).attr('name', this.hidden.attr('name'));
    return this.container.replaceWith(this.input);
  };

  return MentionsInput;

})(MentionsBase);

MentionsContenteditable = (function(_super) {
  var insertMention, mentionTpl;

  __extends(MentionsContenteditable, _super);

  MentionsContenteditable.prototype.selector = '[data-mention]';

  function MentionsContenteditable(input, options) {
    this.input = input;
    this._onSelect = __bind(this._onSelect, this);
    this._addMention = __bind(this._addMention, this);
    MentionsContenteditable.__super__.constructor.call(this, this.input, options);
    this.autocomplete = this.input.editablecomplete({
      matcher: this._getMatcher(),
      suffix: this.marker,
      select: this._onSelect,
      source: this.options.source,
      delay: this.options.delay,
      showAtCaret: this.options.showAtCaret
    });
    this._initValue();
    this._initEvents();
  }

  mentionTpl = function(mention) {
    return "<strong data-mention=\"" + mention.uid + "\">" + mention.value + "</strong>";
  };

  insertMention = function(mention, pos, suffix) {
    var node, range, selection;
    selection = window.getSelection();
    node = selection.focusNode;
    range = selection.getRangeAt(0);
    range.setStart(node, pos.start);
    range.setEnd(node, pos.end);
    range.deleteContents();
    range.insertNode(mention);
    if (suffix) {
      suffix = document.createTextNode(suffix);
      $(suffix).insertAfter(mention);
      range.setStartAfter(suffix);
    } else {
      range.setStartAfter(mention);
    }
    range.collapse(true);
    selection.removeAllRanges();
    selection.addRange(range);
    return mention;
  };

  MentionsContenteditable.prototype._initEvents = function() {
    return this.input.find(this.selector).each((function(_this) {
      return function(i, el) {
        return _this._watch(el);
      };
    })(this));
  };

  MentionsContenteditable.prototype._initValue = function() {
    return this._setValue(this.input.val());
  };

  MentionsContenteditable.prototype._setValue = function(value) {
    var mentionRE;
    mentionRE = /@\[([^\]]+)\]\(([^ \)]+)\)/g;
    value = value.replace(mentionRE, (function(_this) {
      return function(match, value, uid) {
        return mentionTpl({
          value: value,
          uid: uid
        }) + _this.marker;
      };
    })(this));
    return this.input.html(value);
  };

  MentionsContenteditable.prototype._addMention = function(data) {
    var mention, mentionNode;
    mentionNode = $(mentionTpl(data))[0];
    mention = insertMention(mentionNode, data.pos, this.marker);
    return this._watch(mention);
  };

  MentionsContenteditable.prototype._onSelect = function(event, ui) {
    this._addMention(ui.item);
    this.input.trigger("change." + namespace);
    return false;
  };

  MentionsContenteditable.prototype._watch = function(mention) {
    return mention.addEventListener('DOMCharacterDataModified', function(e) {
      var offset, range, sel, text;
      if (e.newValue !== e.prevValue) {
        text = e.target;
        sel = window.getSelection();
        offset = sel.focusOffset;
        $(text).insertBefore(mention);
        $(mention).remove();
        range = document.createRange();
        range.setStart(text, offset);
        range.collapse(true);
        sel.removeAllRanges();
        return sel.addRange(range);
      }
    });
  };

  MentionsContenteditable.prototype.update = function() {
    this._initValue();
    this._initEvents();
    return this.input.focus();
  };

  MentionsContenteditable.prototype.append = function() {
    var piece, pieces, value, _i, _len;
    pieces = 1 <= arguments.length ? __slice.call(arguments, 0) : [];
    value = this.input.html();
    for (_i = 0, _len = pieces.length; _i < _len; _i++) {
      piece = pieces[_i];
      if (typeof piece === 'string') {
        value += piece;
      } else {
        value += mentionTpl({
          value: piece.name,
          uid: piece.uid
        }) + this.marker;
      }
    }
    this.input.html(value);
    this._initEvents();
    return this.input.focus();
  };

  MentionsContenteditable.prototype.setValue = function(value) {
    this._setValue(value);
    return this._initEvents();
  };

  MentionsContenteditable.prototype.getValue = function() {
    var value;
    value = this.input.clone();
    $(this.selector, value).replaceWith(function() {
      var name, uid;
      uid = $(this).data('mention');
      name = $(this).text();
      return "@[" + name + "](" + uid + ")";
    });
    return value.html().replace(this.marker, '');
  };

  MentionsContenteditable.prototype.clear = function() {
    this.input.html('');
    return this._update();
  };

  MentionsContenteditable.prototype.destroy = function() {
    this.input.editablecomplete("destroy");
    this.input.off("." + namespace);
    return this.input.html(this.getValue());
  };

  return MentionsContenteditable;

})(MentionsBase);

$.fn[namespace] = function() {
  var args, options, returnValue;
  options = arguments[0], args = 2 <= arguments.length ? __slice.call(arguments, 1) : [];
  returnValue = this;
  this.each(function() {
    var instance, _ref;
    if (typeof options === 'string' && options.charAt(0) !== '_') {
      instance = $(this).data('mentionsInput');
      if (options in instance) {
        return returnValue = instance[options].apply(instance, args);
      }
    } else {
      if ((_ref = this.tagName) === 'INPUT' || _ref === 'TEXTAREA') {
        return $(this).data('mentionsInput', new MentionsInput($(this), options));
      } else if (this.contentEditable === "true") {
        return $(this).data('mentionsInput', new MentionsContenteditable($(this), options));
      }
    }
  });
  return returnValue;
};
