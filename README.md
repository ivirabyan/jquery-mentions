jquery-mentions
===============
More stable alternative to [podio's jquery.mentionsInput](https://github.com/podio/jquery-mentions-input) plugin, which is currently unmaintained.

Advantages over jquery.mentionsInput:
- Many issues are solved
- Input styles are copied to highlighter automatically
- Support of both textarea and input tags
- Hidden-input with markuped text created automatically
- Uses jQuery UI autocomplete
- The code is much smaller

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

Remote datasource (ajax):

```
$('textarea').mentionsInput({source: 'http://example.com/users.json'})
```
The url is given a query paremeter `term`, like `http://example.com/users.json?term=Foo` and must return a json list of matched values (like the above).

Calling a method:
```
$('textarea').mentionsInput('getValue');
$('textarea').mentionsInput('setValue', 'Hello, @[Alex](user:1)');
```

## Options

#### source
  Data source for the autocomplete. See [jQuery Autocomplete API](http://api.jqueryui.com/autocomplete/#option-source) for available values.
  
  Source data is an array of objects with `uid` and `value` properties: `[{uid: '123', value: 'Alex'}, ...]`. If you want to display an icon in dropdown list, you can add an `image` property to objects in the array.
  
#### delay
  Delay for autocomplete to start searching. Default value is 0. More info in [jQuery Autocomplete API](http://api.jqueryui.com/autocomplete/#option-delay)
#### trigger
  Char which trigger autocomplete, default value is '@'

#### autoFocus
  If this is true, first item is automatically focused in the dropdown. Default is true.

## Methods

#### getValue()
  Returns marked up value.

#### setValue(value)
  Takes marked up value as an argument. For example `'Hey, @[alex](user:1)'`.
  You can also represent mentions as objects, instead of manually marking them up:
  `$textarea.mentionsInput('setValue', 'Hey, ', {name: 'alex', uid: 'user:1'})`

#### clear()
  Clears value. Note that you must use this method insted of manually clearing value of the input

#### destroy()
  Destroys current instance of the plugin
