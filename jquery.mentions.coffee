namespace = "mentionsInput"

Key = LEFT : 37, RIGHT : 39

mimicProperties = [
	'marginTop', 'marginBottom', 'marginLeft', 'marginRight',
	'paddingTop', 'paddingBottom', 'paddingLeft', 'paddingRight',
	'borderTopWidth', 'borderLeftWidth', 'borderBottomWidth', 'borderRightWidth',
	'fontSize', 'fontStyle', 'fontFamily', 'fontWeight', 'lineHeight', 'height', 'boxSizing'
]

Selection =
	get: (input) ->
		start: input[0].selectionStart,
		end: input[0].selectionEnd

	set: (input, start, end=start) ->
		input[0].setSelectionRange(start, end)


settings =
	delay: 0
	trigger: '@'

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
			value = match[1]
		return $.ui.autocomplete.prototype.search.call(@, value, event)

	_renderItem: (ul, item) ->
		li = $('<li>')
		anchor = $('<a>').appendTo(li)
		if item.image
			anchor.append("<img src=\"#{item.image}\" />")
		anchor.append(item.value)
		return li.appendTo(ul)
)


class MentionsInput
	marker: '\uFEFF',

	constructor: (@input, options) ->
		@options = $.extend({}, settings, options)

		if not @options.source
			@options.source = @input.data('source') or []

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
			appendTo: @input.parent()
		)

		@_initValue()
		@_initEvents()

	_initEvents: ->
		@input.on("input.#{namespace}", @_update)
		@input.on("change.#{namespace}", @_update)

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

	_initValue: ->
		value = @input.val()
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
		highlighter.prependTo(@container)

		content = $('<div>', {'class': 'highlighter-content'})
		highlighter.append(content)

		@input.css('backgroundColor', 'transparent')
		for property in mimicProperties
			highlighter.css(property, @input.css(property))
		return highlighter

	_getMatcher: ->
		allowedChars = '[^' + @options.trigger + ']'
		return '\\B[' + @options.trigger + '](' + allowedChars + '{0,20})'

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
			value = value.replace(markedName, "@[#{mention.name}](#{mention.uid})")

		@hidden.val(value)
		@highlighterContent.html(hlContent)

	_updateVScroll: =>
		scrollTop = @input.scrollTop()
		@highlighterContent.css(top: "-#{scrollTop}px")
		@highlighter.height(@input.height())

	_updateHScroll: =>
		scrollLeft = @input.scrollLeft()
		@highlighterContent.css(left: "-#{scrollLeft}px")
		@highlighterContent.width(@input.get(0).scrollWidth)

	_replaceWithSpaces: (value, what) ->
		return value.replace(what, Array(what.length).join(' '))

	_cutChar: (value, index) ->
		return value.substring(0, index) + value.substring(index + 1)

	append: (pieces...) ->
		value = @input.val()
		for piece in pieces
			if typeof piece == 'string'
				value += piece
			else
				@_addMention({name: piece.name, uid: piece.uid, pos: value.length})
				value += @_mark(piece.name)
		@input.val(value)
		@_updateValue()

	clear: ->
		@input.val('')
		@_update()

	destroy: ->
		@input.areacomplete("destroy")
		@input.off(".#{namespace}").attr('name', @hidden.attr('name'))
		@container.replaceWith(@input)

$.fn[namespace] = (options, args...) ->
	this.each(->
		if typeof options == 'string' and options.charAt(0) != '_'
			instance = $(this).data('mentionsInput')
			console.log('hello', options, instance, options in instance)
			if options of instance
				console.log('hi tehre')
				instance[options](args...)
		else
			$(this).data('mentionsInput', new MentionsInput($(this), options))
	)
