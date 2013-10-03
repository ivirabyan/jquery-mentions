namespace = "mentionsInput"

Key = LEFT : 37, RIGHT : 39

mimicProperties = [
	'marginTop', 'marginBottom', 'marginLeft', 'marginRight',
	'paddingTop', 'paddingBottom', 'paddingLeft', 'paddingRight',
	'borderTopWidth', 'borderLeftWidth', 'borderBottomWidth', 'borderRightWidth',
	'fontSize', 'fontStyle', 'fontFamily', 'lineHeight', 'height',
	'backgroundColor'
]

Selection =
	get: (input) ->
		start: input[0].selectionStart,
		end: input[0].selectionEnd

	set: (input, start, end=start) ->
		input[0].setSelectionRange(start, end)


settings =
	source: []
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
		@mentions = []
		@options = $.extend(settings, options)

		@input.addClass('input')

		container = $('<div>', {'class': 'mentions-input'})
		container.css('display', @input.css('display'))
		@container = @input.wrapAll(container).parent()

		@hidden = @createHidden()
		@highlighter = @createHighlighter()
		@highlighterContent = $('div', @highlighter)

		@autocomplete = @input.areacomplete(
			matcher: @getMatcher(),
			suffix: @marker,
			select: @onSelect,
			source: @options.source,
			delay: @options.delay,
		)

		@initValue()
		@initEvents()

	initEvents: ->
		@input.on('input', @update)
		@input.on('change', @update)

		@input.on('keydown', (event) =>
			setTimeout((=> @handleLeftRight(event)), 10)
		)

		tagName = @input.prop("tagName")
		if tagName == "INPUT"
			@input.on('focus', =>
				@interval = setInterval(@updateHScroll, 10)
			)
			@input.on('blur', =>
				setTimeout(@updateHScroll, 10)
				clearInterval(@interval)
			)
		else if tagName == "TEXTAREA"
			@input.on('scroll', (=> setTimeout(@updateVScroll, 10)))
			@input.on('resize', (=> setTimeout(@updateVScroll, 10)))

	initValue: ->
		value = @input.val()
		mentionRE = /@\[([^\]]+)\]\(([^ \)]+)\)/g
		markedValue = value.replace(mentionRE, @mark('$1'))
		@input.val(markedValue)

		match = mentionRE.exec(value)
		while match
			@addMention(
				name: match[1],
				uid: match[2],
				pos = markedValue.indexOf(@mark(match[1]))
			)
			match = mentionRE.exec(value)
		@updateValue()

	createHidden: ->
		hidden = $('<input>', {type: 'hidden', name: @input.attr('name')})
		hidden.appendTo(@container)
		@input.removeAttr('name')
		return hidden

	createHighlighter: ->
		highlighter = $('<div>', {'class': 'highlighter'})
		highlighter.prependTo(@container)
		
		content = $('<div>', {'class': 'highlighter-content'})
		highlighter.append(content)

		for property in mimicProperties
			highlighter.css(property, @input.css(property))

		@input.css('backgroundColor', 'transparent')
		return highlighter

	getMatcher: ->
		allowedChars = '[^' + @options.trigger + ']'
		return '\\B[' + @options.trigger + '](' + allowedChars + '{0,20})'

	handleLeftRight: (event) =>
		if event.keyCode == Key.LEFT or event.keyCode == Key.RIGHT
			value = @input.val()
			sel = Selection.get(@input)
			delta = if event.keyCode == Key.LEFT then -1 else 1
			deltaStart = if value.charAt(sel.start) == @marker then delta else 0
			deltaEnd = if value.charAt(sel.end) == @marker then delta else 0
			
			if deltaStart or deltaEnd
				Selection.set(@input, sel.start + deltaStart, sel.end + deltaEnd)

	mark: (name) =>
		name + @marker

	update: =>
		@updateMentions()
		@updateValue()

	updateMentions: =>
		value = @input.val()
		for mention, i in @mentions[..]
			marked = @mark(mention.name)
			index = value.indexOf(marked)
			if index == -1
				@mentions = @mentions.splice(i + 1, 1)
			else
				mention.pos = index
			value = @replaceWithSpaces(value, marked)

		# remove orphan markers
		newval = @input.val()
		while (index = value.indexOf(@marker)) >= 0
			value = @cutChar(value, index)
			newval = @cutChar(newval, index)
		selection = Selection.get(@input)
		@input.val(newval)
		Selection.set(@input, selection.start)

	addMention: (mention) =>
		@mentions.push(mention)

	onSelect: (event, ui) =>
		@addMention(name: ui.item.value, pos: ui.item.pos, uid: ui.item.uid)

	updateValue: =>
		value = hlContent = @input.val()

		for mention in @mentions
			markedName = @mark(mention.name)
			hlContent = hlContent.replace(markedName, "<strong>#{mention.name}</strong>")
			value = value.replace(markedName, "@[#{mention.name}](#{mention.uid})")

		@hidden.val(value)
		@highlighterContent.html(hlContent)

	updateVScroll: =>
		scrollTop = @input.scrollTop()
		@highlighterContent.css(top: "-#{scrollTop}px")
		@highlighter.height(@input.height())

	updateHScroll: =>
		scrollLeft = @input.scrollLeft()
		@highlighterContent.css(left: "-#{scrollLeft}px")
		@highlighterContent.width(@input.get(0).scrollWidth)

	replaceWithSpaces: (value, what) ->
		return value.replace(what, Array(what.length).join(' '))

	cutChar: (value, index) ->
		return value.substring(0, index) + value.substring(index + 1)

$.fn[namespace] = (options) ->
	this.each(->
		$(this).data('mentionsInput', new MentionsInput($(this), options))
	)
		