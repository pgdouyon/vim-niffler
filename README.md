Niffler
=======

> "These're nifflers," said Hagrid, when the class had gathered around.  "Yeh
> find 'em down mines mostly.  They like sparkly stuff...useful little
> treasure detectors."

Nifflers are fluffy, mole-like creatures that like to dig for treasure.
Vim-Niffler, on the other hand, is a fast, lightweight, fuzzy, file finder for
Vim and is heavily inspired by [FZF][].

I made Vim-Niffler because all the other fuzzy file finders I tried were either
really slow (Unite) or didn't integrate well with GVim (FZF).  If you use Vim in
the terminal, I highly recommend FZF over this plugin; it's faster and more
feature complete.  This plugin is really just meant to be a fuzzy file finder
for the GUI.


Usage
-----

Niffler differs from other fuzzy file finders in that it doesn't perform a fuzzy
search by default.  Instead it searches for an exact match of the text typed but
you can insert a "fuzzy character" to indicate exactly which part of the query
should use fuzzy matching.  This is probably best explained by an example, the
fuzzy char in this case will be a "*":

* `oba` will match `foobar` but not `foobuzzbar`
* `ob*a` will match `foobar` and `foobuzzbar`
* `f*ob*ar` will match `foobar`, `foobuzzbar`, and `fizzboobar`, but not `foobaz`

The default fuzzy char is `;` but can be changed with `g:niffler_fuzzy_char`

The beginning and end of the query are fuzzy by default but you can use `^` and
`$` to specify an exact match at either end:

* `^foo` will match `foobar` but not `buzzfoobar`
* `foo$` will match `buzzfoo` but not `buzzfoobar`


Niffler has several different modes:

| Command         | Description                                                           |
| --------------- | --------------------------------------------------------------------- |
| `Niffler`       | Fuzzy file search                                                     |
| `NifflerVCS`    | Fuzzy file search from git root directory of current file             |
| `NifflerNew`    | Fuzzy search for directory and enter new file name                    |
| `NifflerNewVCS` | Same as `NifflerNew` starting from git root directory of current file |
| `NifflerMRU`    | Fuzzy file search on MRU cache                                        |

All commands except for `NifflerMRU` take optional arguments:

* Directory to search from (default: ~)
* GNU find arguments separated by spaces

The size of the MRU cache (default 500) can be configured with the variable
`g:niffler_mru_max_history`.


Requirements
------------

Niffler currently requires a `find` utility and MacOSX or any \*nix OS for full
support.  Niffler is not fully supported on Windows, only the NifflerMRU command
is available.


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
