namespace = "mentionsContenteditable"

settings =
    delay: 0
    trigger: '@'


mentionTpl = (mention) ->
    "<span data-mention=\"#{mention.uid}\">#{mention.value}</span>"


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


$.widget( "ui.editablecomplete", $.ui.autocomplete,
    options: $.extend({}, $.ui.autocomplete.prototype.options,
        matcher: "(\\b[^,]*)",
        suffix: ', ',
        showAtCaret: false
    )

    _create: ->
        @overriden =
            select: @options.select
            focus: @options.focus
        @options.select = $.proxy(@selectCallback, @)
        @options.focus = $.proxy(@focusCallback, @)

        @marker = $("<span id='__autocomplete-marker'/>")[0]

        $.ui.autocomplete.prototype._create.call(@)
        @matcher = new RegExp(@options.matcher + '$')

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

    focusCallback: ->
        if @overriden.focus
            return @overriden.focus(event, ui)
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

            if @options.showAtCaret
                range = sel.getRangeAt 0
                boundary = range.cloneRange()
                boundary.setStart node, @start
                boundary.collapse true
                boundary.insertNode @marker
                boundary.detach()
                @options.position.of = @marker

            value = match[1]
        return $.ui.autocomplete.prototype.search.call(@, value, event)

    close: (event) ->
        @marker.remove()
        @element.change()
        return $.ui.autocomplete.prototype.close.call(@, event)

    _renderItem: (ul, item) ->
        li = $('<li>')
        anchor = $('<a>').appendTo(li)
        if item.image
            anchor.append("<img src=\"#{item.image}\" />")
        anchor.append(item.value)
        return li.appendTo(ul)
)


class MentionsContenteditable
    marker: '\uFEFF',
    selector: '[data-mention]',

    constructor: (@input, options) ->
        @options = $.extend({}, settings, options)

        if not @options.source
            @options.source = @input.data('source') or []

        @input.addClass 'input'

        @autocomplete = @input.editablecomplete(
            matcher: @_getMatcher(),
            suffix: @marker,
            select: @_onSelect,
            source: @options.source,
            delay: @options.delay,
            showAtCaret: true
        )
        @_initValue()
        @_initEvents()


    _initEvents: ->
        @input.find(@selector).each (i, el) =>
            @_watch el

    _initValue: ->
        value = @input.html()
        mentionRE = /@\[([^\]]+)\]\(([^ \)]+)\)/g
        value = value.replace mentionRE, (match, value, uid) =>
            mentionTpl(value: value, uid: uid) + @marker
        @input.html value
        

    _getMatcher: ->
        allowedChars = '[^' + @options.trigger + ']'
        return '\\B[' + @options.trigger + '](' + allowedChars + '{0,20})'

    _addMention: (data) =>
        mentionNode = $(mentionTpl data)[0]
        mention = insertMention mentionNode, data.pos, @marker
        @_watch mention

    _onSelect: (event, ui) =>
        @_addMention ui.item
        return false

    _watch: (mention) ->
        mention.addEventListener 'DOMCharacterDataModified', (e) ->
            if e.newValue != e.prevValue
                text = e.target
                sel = window.getSelection()
                offset = sel.focusOffset

                $(mention).replaceWith text

                range = document.createRange()
                range.setStart text, offset
                range.collapse true
                sel.removeAllRanges()
                sel.addRange range

    # append: (pieces...) ->
    #     value = @input.val()
    #     for piece in pieces
    #         if typeof piece == 'string'
    #             value += piece
    #         else
    #             @_addMention({name: piece.name, uid: piece.uid, pos: value.length})
    #             value += @_mark(piece.name)
    #     @input.val(value)

    getValue: ->
        value = @input.clone()
        $(@selector, value).replaceWith ->
            uid = $(this).data 'mention'
            name = $(this).text()
            return "@[#{name}](#{uid})"
        value.html().replace(@marker, '')

    clear: ->
        @input.html('')
        @_update()

    destroy: ->
        @input.editablecomplete "destroy"
        @input.off ".#{namespace}"
        @input.html @getValue()


Object.defineProperty MentionsContenteditable::, 'mentions', 
    get: -> 
        mentions = []
        @input.find(@selector).each ->
            mentions.push
                value: $(this).text(),
                uid: $(this).data 'mention'
        return mentions

@MentionsContenteditable = MentionsContenteditable

$.fn[namespace] = (options, args...) ->
    returnValue = this

    this.each(->
        if typeof options == 'string' and options.charAt(0) != '_'
            instance = $(this).data('mentionsContenteditable')
            if options of instance
                returnValue = instance[options](args...)
        else
            $(this).data('mentionsContenteditable', new MentionsContenteditable($(this), options))
    )
    return returnValue