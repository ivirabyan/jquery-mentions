
Changes
===============
This is a modification on top of the existing plugin by ivirabyan/jquery-mentions , I have added support for npm and CommonJS

jquery-mentions
===============
Adds mentioning support to your text fields.

It's a more robust alternative to [podio's jquery.mentionsInput](https://github.com/podio/jquery-mentions-input) plugin.

Live example: http://ivirabyan.github.io/jquery-mentions/

Advantages over jquery.mentionsInput:
- Many issues are solved
- Input styles are copied to highlighter automatically
- Support for both textarea and input tags
- Support for contenteditable (and as a result support for some WYSIWYG editors)
- Hidden-input with markuped text created automatically
- Uses jQuery UI autocomplete

Solved issues of jquery.mentionsInput:
- Adding spaces before mention shows overlay
- Scrolling to bottom inside textarea moves text, but not highlights
- Typing email adress activates mentions
- Inserting same mentions multiple times
- Prepopulate input with text

## Usage
For this plugin to work you need to include [jQuery Autocomplete](http://jqueryui.com/autocomplete/) to your page.

```
var data = [
    {value: 'alex', uid: 'user:1'},
    {value: 'andrew', uid: 'user:2'},
    {value: 'angry birds', uid: 'game:5'},
    {value: 'assault', uid: 'game:3'}
];

$('textarea').mentionsInput({source: data});
```

##### Remote datasource (ajax):

```
$('textarea').mentionsInput({source: 'http://example.com/users.json'})
```
The url is given a query paremeter `term`, like `http://example.com/users.json?term=Foo` and must return a json list of matched values (like the above).

You can also provide custom function to `source` argument, for more info take a look at [jQuery Autocomplete docs](http://api.jqueryui.com/autocomplete/#option-source).


##### Calling a method:
```
$('textarea').mentionsInput('getValue');
$('textarea').mentionsInput('setValue', 'Hello, @[Alex](user:1)');
```

##### Getting value:
`$('textarea').mentionsInput('getValue')` -> `Hello, @[Alex](user:1)`
`$('textarea').mentionsInput('getRawValue')` -> `Hello, Alex`

Don't use textarea value directly, because it contains special characters, used by plugin internally. Always use methods.

##### WYSIWYG editors

WARNING: This plugin does not currently work with editors, which use iframe.

To create WYSIWYG editor on your site, usually you create `<textarea>` tag, and then your editor replaces it with editor's visual representation, including element with `contenteditable="true"` attribute. So, to make `mentionsInput` plugin work, you need to apply the plugin to element  with `contenteditable="true"`. If you apply the plugin to your `<textarea>`, it'll not work.
For example:
```
    <textarea id="content"></textarea>
    <script>
        $('#content').myEditor();
        // Now your editor is initialized, find element with contenteditable.
        // For particular plugin you may find a better way to get such an element,
        // maybe even write your own plugin.
        var elEditable = $('[contenteditable=true]');
        elEditable.mentionsInput({...});
    </script>
```

## Options

#### source
  Data source for the autocomplete. See [jQuery Autocomplete API](http://api.jqueryui.com/autocomplete/#option-source) for available values.
  
  Source data is an array of objects with `uid` and `value` properties: `[{uid: '123', value: 'Alex'}, ...]`. If you want to display an icon in dropdown list, you can add an `image` property to objects in the array.

### suffix
  String to add to selected mention when it is inserted in text. Can be usefull if you wish to automatically insert a space after mention. For that case: `$textarea.mentionsInput({suffix: ' '})`
  Note: only supported for textarea and input. Contenteditable does not support this option yet.

#### trigger
  Char which trigger autocomplete, default value is '@'. Multiple chars are supported, so if you set trigger='@#', both will trigger a search.

#### widget
  Name of the autocomplete widget to use. May be useful when you want to somehow customize appearance of autocomplete widget, for example add headers to items list. You must inherit from widget, used internally (`ui.areacomplete` when you use textarea, and `ui.editablecomplete` when you use div with `contenteditable=true`).

#### autocomplete
  Options to pass to jQuery Autocomplete widget. Default is `{delay: 0, autoFocus: true}`.

## Methods

#### getValue()
  Returns marked up value.

#### getRawValue()
  Returns value without any markup

#### setValue(value)
  Takes marked up value as an argument. For example `'Hey, @[alex](user:1)'`.
  You can also represent mentions as objects, instead of manually marking them up:
  `$textarea.mentionsInput('setValue', 'Hey, ', {name: 'alex', uid: 'user:1'})`

#### getMentions()
  Returns an array of all mentions contained within the text, like this:
  ```
  [
    {name: 'alex', uid: 'user:1'},
    {name: 'andrew', uid: 'user:2'}
  ]
  ```

#### clear()
  Clears value. Note that you must use this method insted of manually clearing value of the input

#### destroy()
  Destroys current instance of the plugin
