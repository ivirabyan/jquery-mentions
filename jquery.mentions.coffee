namespace = "mentionsInput"


Selection =
    get: (input) ->
        start: input[0].selectionStart,
        end: input[0].selectionEnd

    set: (input, start, end=start) ->
        if input[0].selectionStart
            input[0].selectStart = start
            input[0].selectionEnd = end


settings =
    delay: 0
    trigger: '@',
    autoFocus: true



$.widget( "ui.areacomplete", $.ui.autocomplete,
    options: $.extend({}, $.ui.autocomplete.prototype.options,
        matcher: "(\\b[^,]*)",
        suffix: ', '
    )

    _create: ->
        @overriden =
            select: @options.select
            focus: @options.focus
        @options.select = $.proxy(@selectCallback, @)
        @options.focus = $.proxy(@focusCallback, @)

        $.ui.autocomplete.prototype._create.call(@)
        @matcher = new RegExp(@options.matcher + '$')

    selectCallback: (event, ui) ->
        value = @_value()
        before = value.substring(0, @start)
        after = value.substring(@end)
        newval = ui.item.value + @options.suffix
        value = before + newval + after
        if @overriden.select
            ui.item.pos = @start
            if @overriden.select(event, ui) == false
                return false

        @_value(value)
        @element.change()
        Selection.set(@element, before.length + newval.length)
        return false

    focusCallback: ->
        if @overriden.focus
            return @overriden.focus(event, ui)
        return false

    search: (value, event) ->
        if not value
            value = @_value()
            pos = Selection.get(@element).start
            value = value.substring(0, pos)
            match = @matcher.exec(value)
            if not match
                return ''

            @start = match.index
            @end = match.index + match[0].length
            @searchTerm = match[1]
        return $.ui.autocomplete.prototype.search.call(@, @searchTerm, event)

    _renderItem: (ul, item) ->
        li = $('<li>')
        anchor = $('<a>').appendTo(li)
        if item.image
            anchor.append("<img src=\"#{item.image}\" />")
        value = item.value.replace(this.searchTerm.substring(), "<strong>$&</strong>")
        anchor.append(value)
        return li.appendTo(ul)
)


$.widget( "ui.editablecomplete", $.ui.areacomplete,
    options: $.extend({}, $.ui.areacomplete.prototype.options,
        showAtCaret: false
    )

    selectCallback: (event, ui) ->
        pos = {start: @start, end: @end}
        if @overriden.select
            ui.item.pos = pos
            if @overriden.select(event, ui) == false
                return false

        mention = document.createTextNode ui.item.value
        insertMention mention, pos, @options.suffix
        @element.change()
        return false

    search: (value, event) ->
        if not value
            sel = window.getSelection()
            node = sel.focusNode
            value = node.textContent
            pos = sel.focusOffset
            value = value.substring(0, pos)
            match = @matcher.exec(value)
            if not match
                return ''

            @start = match.index
            @end = match.index + match[0].length
            @_setDropdownPosition node
            @searchTerm = match[1]
        return $.ui.autocomplete.prototype.search.call(@, @searchTerm, event)

    _setDropdownPosition: (node) ->
        if @options.showAtCaret
            boundary = document.createRange()
            boundary.setStart node, @start
            boundary.collapse true
            rect = boundary.getClientRects()[0]
            posX = rect.left + (window.scrollX || window.pageXOffset)
            posY = rect.top + rect.height + (window.scrollY || window.pageYOffset)
            @options.position.of = document
            @options.position.at = "left+#{posX} top+#{posY}"
)


class MentionsBase
    marker: '\uFEFF',

    constructor: (@input, options) ->
        @options = $.extend({}, settings, options)
        if not @options.source
            @options.source = @input.data('source') or []

    _getMatcher: ->
        allowedChars = '[^' + @options.trigger + ']'
        return '\\B[' + @options.trigger + '](' + allowedChars + '{0,20})'

    _markupMention: (mention) ->
        return "@[#{mention.name}](#{mention.uid})"


class MentionsInput extends MentionsBase
    Key = LEFT : 37, RIGHT : 39

    mimicProperties = [
        'backgroundColor', 'marginTop', 'marginBottom', 'marginLeft', 'marginRight',
        'paddingTop', 'paddingBottom', 'paddingLeft', 'paddingRight',
        'borderTopWidth', 'borderLeftWidth', 'borderBottomWidth', 'borderRightWidth',
        'fontSize', 'fontStyle', 'fontFamily', 'fontWeight', 'lineHeight', 'height', 'boxSizing'
    ]

    constructor: (@input, options) ->
        super @input, options

        @mentions = []
        @input.addClass('input')

        container = $('<div>', {'class': 'mentions-input'})
        container.css('display', @input.css('display'))
        @container = @input.wrapAll(container).parent()

        @hidden = @_createHidden()
        @highlighter = @_createHighlighter()
        @highlighterContent = $('div', @highlighter)

        @input.focus(=>
            @highlighter.addClass('focus')
        ).blur(=>
            @highlighter.removeClass('focus')
        )

        @autocomplete = @input.areacomplete(
            matcher: @_getMatcher(),
            suffix: @marker,
            select: @_onSelect,
            source: @options.source,
            delay: @options.delay,
            appendTo: @input.parent(),
            autoFocus: @options.autoFocus
        )

        @_setValue(@input.val())
        @_initEvents()

    _initEvents: ->
        @input.on("input.#{namespace} change.#{namespace}", @_update)

        @input.on("keydown.#{namespace}", (event) =>
            setTimeout((=> @_handleLeftRight(event)), 10)
        )

        tagName = @input.prop("tagName")
        if tagName == "INPUT"
            @input.on("focus.#{namespace}", =>
                @interval = setInterval(@_updateHScroll, 10)
            )
            @input.on("blur.#{namespace}", =>
                setTimeout(@_updateHScroll, 10)
                clearInterval(@interval)
            )
        else if tagName == "TEXTAREA"
            @input.on("scroll.#{namespace}", (=> setTimeout(@_updateVScroll, 10)))
            @input.on("resize.#{namespace}", (=> setTimeout(@_updateVScroll, 10)))

    _setValue: (value) ->
        mentionRE = /@\[([^\]]+)\]\(([^ \)]+)\)/g
        markedValue = value.replace(mentionRE, @_mark('$1'))
        @input.val(markedValue)

        match = mentionRE.exec(value)
        while match
            @_addMention(
                name: match[1],
                uid: match[2],
                pos = markedValue.indexOf(@_mark(match[1]))
            )
            match = mentionRE.exec(value)
        @_updateValue()

    _createHidden: ->
        hidden = $('<input>', {type: 'hidden', name: @input.attr('name')})
        hidden.appendTo(@container)
        @input.removeAttr('name')
        return hidden

    _createHighlighter: ->
        highlighter = $('<div>', {'class': 'highlighter'})
        
        if @input.prop("tagName") == "INPUT"
            highlighter.css('whiteSpace', 'pre')
        else
            highlighter.css('whiteSpace', 'pre-wrap')
            highlighter.css('wordWrap', 'break-word')
        
        content = $('<div>', {'class': 'highlighter-content'})
        highlighter.append(content).prependTo(@container)

        for property in mimicProperties
            highlighter.css property, @input.css(property)
        @input.css 'backgroundColor', 'transparent'
        return highlighter

    _handleLeftRight: (event) =>
        if event.keyCode == Key.LEFT or event.keyCode == Key.RIGHT
            value = @input.val()
            sel = Selection.get(@input)
            delta = if event.keyCode == Key.LEFT then -1 else 1
            deltaStart = if value.charAt(sel.start) == @marker then delta else 0
            deltaEnd = if value.charAt(sel.end) == @marker then delta else 0

            if deltaStart or deltaEnd
                Selection.set(@input, sel.start + deltaStart, sel.end + deltaEnd)

    _mark: (name) =>
        name + @marker

    _update: =>
        @_updateMentions()
        @_updateValue()

    _updateMentions: =>
        value = @input.val()
        if value
            for mention, i in @mentions[..]
                marked = @_mark(mention.name)
                index = value.indexOf(marked)
                if index == -1
                    @mentions.splice(i, 1)
                else
                    mention.pos = index
                value = @_replaceWithSpaces(value, marked)

            # remove orphan markers
            newval = @input.val()
            while (index = value.indexOf(@marker)) >= 0
                value = @_cutChar(value, index)
                newval = @_cutChar(newval, index)

            if value != newval
                selection = Selection.get(@input)
                @input.val(newval)
                Selection.set(@input, selection.start)

    _addMention: (mention) =>
        @mentions.push(mention)

    _onSelect: (event, ui) =>
        @_addMention(name: ui.item.value, pos: ui.item.pos, uid: ui.item.uid)

    _updateValue: =>
        value = hlContent = @input.val()
        for mention in @mentions
            markedName = @_mark(mention.name)
            hlContent = hlContent.replace(markedName, "<strong>#{mention.name}</strong>")
            value = value.replace(markedName, @_markupMention(mention))

        @hidden.val(value)
        @highlighterContent.html(hlContent)

    _updateVScroll: =>
        scrollTop = @input.scrollTop()
        @highlighterContent.css(top: "-#{scrollTop}px")
        @highlighter.height(@input.height())

    _updateHScroll: =>
        scrollLeft = @input.scrollLeft()
        @highlighterContent.css(left: "-#{scrollLeft}px")

    _replaceWithSpaces: (value, what) ->
        return value.replace(what, Array(what.length).join(' '))

    _cutChar: (value, index) ->
        return value.substring(0, index) + value.substring(index + 1)

    setValue: (pieces...) ->
        value = ''
        for piece in pieces
            if typeof piece == 'string'
                value += piece
            else
                value += @_markupMention(piece)
        @_setValue(value)

    getValue: ->
        return @hidden.val()

    getMentions: ->
        return @mentions

    clear: ->
        @input.val('')
        @_update()

    destroy: ->
        @input.areacomplete("destroy")
        @input.off(".#{namespace}").attr('name', @hidden.attr('name'))
        @container.replaceWith(@input)


class MentionsContenteditable extends MentionsBase
    selector: '[data-mention]',

    constructor: (@input, options) ->
        super @input, options
        @autocomplete = @input.editablecomplete(
            matcher: @_getMatcher(),
            suffix: @marker,
            select: @_onSelect,
            source: @options.source,
            delay: @options.delay,
            autoFocus: @options.autoFocus,
            showAtCaret: @options.showAtCaret
        )
        @_setValue(@input.html())
        @_initEvents()

    mentionTpl = (mention) ->
        "<strong data-mention=\"#{mention.uid}\">#{mention.value}</strong>"

    insertMention = (mention, pos, suffix) ->
        selection = window.getSelection()
        node = selection.focusNode

        # delete old content and insert mention
        range = selection.getRangeAt 0
        range.setStart node, pos.start
        range.setEnd node, pos.end
        range.deleteContents()

        range.insertNode mention

        if suffix
            suffix = document.createTextNode suffix
            $(suffix).insertAfter mention
            range.setStartAfter suffix
        else
            range.setStartAfter mention

        range.collapse true
        selection.removeAllRanges()
        selection.addRange range
        return mention

    _initEvents: ->
        @input.find(@selector).each (i, el) =>
            @_watch el

    _setValue: (value) ->
        mentionRE = /@\[([^\]]+)\]\(([^ \)]+)\)/g
        value = value.replace mentionRE, (match, value, uid) =>
            mentionTpl(value: value, uid: uid) + @marker
        @input.html value

    _addMention: (data) =>
        mentionNode = $(mentionTpl data)[0]
        mention = insertMention mentionNode, data.pos, @marker
        @_watch mention

    _onSelect: (event, ui) =>
        @_addMention ui.item
        @input.trigger "change.#{namespace}"
        return false

    _watch: (mention) ->
        mention.addEventListener 'DOMCharacterDataModified', (e) ->
            if e.newValue != e.prevValue
                text = e.target
                sel = window.getSelection()
                offset = sel.focusOffset

                $(text).insertBefore mention
                $(mention).remove()

                range = document.createRange()
                range.setStart text, offset
                range.collapse true
                sel.removeAllRanges()
                sel.addRange range

    update: ->
        @_initValue()
        @_initEvents()
        @input.focus()

    setValue: (pieces...) ->
        value = ''
        for piece in pieces
            if typeof piece == 'string'
                value += piece
            else
                value += @_markupMention(piece)
        @_setValue(value)
        @_initEvents()
        @input.focus()

    getValue: ->
        value = @input.clone()
        $(@selector, value).replaceWith ->
            uid = $(this).data 'mention'
            name = $(this).text()
            return @_markupMention({name: name, uid: uid})
        value.html().replace(@marker, '')

    clear: ->
        @input.html('')
        @_update()

    destroy: ->
        @input.editablecomplete "destroy"
        @input.off ".#{namespace}"
        @input.html @getValue()



$.fn[namespace] = (options, args...) ->
    returnValue = this

    this.each(->
        if typeof options == 'string' and options.charAt(0) != '_'
            instance = $(this).data('mentionsInput')
            if options of instance
                returnValue = instance[options](args...)
        else
            if this.tagName in ['INPUT', 'TEXTAREA']
                $(this).data 'mentionsInput', new MentionsInput($(this), options)
            else if this.contentEditable == "true"
                $(this).data 'mentionsInput', new MentionsContenteditable($(this), options)
    )
    return returnValue
