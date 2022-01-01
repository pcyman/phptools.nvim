# PhpTools

Useful lua functions for php development. Mostly for personal use.

## Requirements

* neovim 0.6+
* treesitter with php grammar installed

## Installation

Install the plugin using your favorite package manager. Packer example:
```lua
  use {'pcyman/phptools.nvim', ft = 'php'}
```

Run somewhere in your config:
```lua
require('phptools').setup()
```

## Functions

### Getter and setter generation

Generates getters and setters for property under cursor or for multiple properties (in visual mode)

Lua:
```lua
require'phptools.getset'.generate_getset() -- under cursor
require'phptools.getset'.generate_getset('v') --visual mode
```

Vim commands:
```
PhpToolsGetSet
PhpToolsGetSetVisual
```

Assumes properties have visibility and type specified:
```php
    private string $name;
```

### Empty unit test with mocks generation

Creates a unit test for currently open class with classes in constructor mocked.

Lua:
```lua
lua require'phptools.unitgen'.generate_test()
```

Vim commands:
```
PhpToolsGenTest
```

Assumptions:
* assumes prophecy for mocking
* assumes class is somewhere in the `src` directory in the project
* assumes tests are somewhere in the `tests` directory in the project
* assumes `composer.json` is located in the root of the working directory
* assumes namespaces for the `/src` and `/tests` dirs are defined in `composer.json`
