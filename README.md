Niffler
=======

> "These're nifflers," said Hagrid, when the class had gathered around.  "Yeh
> find 'em down mines mostly.  They like sparkly stuff...useful little
> treasure detectors."

Nifflers are fluffy, mole-like creatures that like to dig for treasure.
Vim-niffler, on the other hand, is a fast, lightweight, fuzzy, file finder for
Vim and is heavily inspired by [FZF][].

I made vim-niffler because all the other fuzzy file finders I tried were either
really slow (Unite) or didn't integrate well with GVim (FZF).  If you use Vim in
the terminal, I highly recommend FZF over this plugin; it's faster and more
feature complete.  This plugin is really just meant to be a fuzzy file finder
for the GUI.


Usage
-----

Niffler differs from other fuzzy file finders in that it doesn't
perform a fuzzy search by default.  Instead it searches for an exact match of
the text typed but you can insert a "fuzzy character" to indicate where you want
the exact match to end and fuzzy searching to begin.  This is probably best
explained by an example, the fuzzy char in this case will be a "*":

* `foo` will match `foobar` but not `floobar`
* `f*oo` will match `foobar` and `floobar`
* `f*oo*bar` will match `foobar`, and `floobar`, but not `foobaar`

The default fuzzy char is `;` but can be changed with `g:niffler_fuzzy_char`

You can also use `^` and `$` to specify the beginning and end of a match:

* `^foo` will match `foobar` but not `floofoobar`
* `foo$` will match `floofoo` but not `floofoobar`


Niffler has several different modes:

| Command | Description |
| ------- | ----------- |
| `Niffler` | Fuzzy file search |
| `NifflerVCS` | Fuzzy file search from git root directory |
| `NifflerNew` | Fuzzy search for directory and enter new file name |
| `NifflerNewVCS` | Same as `NifflerNew` starting from git root directory |
| `NifflerMRU` | Fuzzy file search on MRU cache |

All commands except for `NifflerMRU` take optional arguments:

* Directory to search from (default: ~)
* GNU find arguments separated by spaces

The size of the MRU cache (default 500) can be configured with the variable
`g:niffler_mru_max_history`.


Requirements
------------

Niffler currently requires a `find` utility and MacOSX or any \*nix OS.  Niffler
currently does not work on Windows.


Installation
------------

* [Pathogen][]
    * `cd ~/.vim/bundle && git clone https://github.com/pgdouyon/vim-niffler.git`
* [Vundle][]
    * `Plugin 'pgdouyon/vim-niffler'`
* [NeoBundle][]
    * `NeoBundle 'pgdouyon/vim-niffler'`
* [Vim-Plug][]
    * `Plug 'pgdouyon/vim-niffler'`
* Manual Install
    * Copy all the files into the appropriate directory under `~/.vim` on \*nix or
      `$HOME/_vimfiles` on Windows


License
-------

Copyright (c) 2014 Pierre-Guy Douyon.  Distributed under the MIT License.


[FZF]: https://github.com/junegunn/fzf
[Pathogen]: https://github.com/tpope/vim-pathogen
[Vundle]: https://github.com/gmarik/Vundle.vim
[NeoBundle]: https://github.com/Shougo/neobundle.vim
[Vim-Plug]: https://github.com/junegunn/vim-plug
