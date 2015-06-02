Niffler
=======

> "These're nifflers," said Hagrid, when the class had gathered around.  "Yeh
> find 'em down mines mostly.  They like sparkly stuff...useful little
> treasure detectors."

Nifflers are fluffy, mole-like creatures that like to dig for treasure.
Vim-Niffler, on the other hand, is a fast, lightweight, fuzzy, file finder for
Vim and is heavily inspired by [FZF][].

I made Vim-Niffler because all the other fuzzy file finders I tried were either
too slow without caching (Unite, CtrlP), too complicated (Unite), had a hideous
codebase (CtrlP), or didn't support opening the fuzzy finder in the current
window (FZF).

If I had known about `g:ctrlp_user_command="ag %s"` and `g:ctrlp_use_caching=0`
I probably would have never made Niffler, but now that I have it's nice to have
a small, legible codebase that makes adding new features/changing core
functionality a breeze.


Usage
-----

Niffler differs from other fuzzy file finders in that it doesn't perform a
fuzzy search by default.  Instead it searches for an exact match of the text
typed but you can insert a "fuzzy character" to specify which part of the query
should match any string of characters.  This works exactly like the "\*"
wildcard character in most shells:

* `izzbu` will match `fizzbuzz` but not `fizzbazbuzz`
* `izz*bu` will match `fizzbuzz` and `fizzbazbuzz`

The default fuzzy char is `*` but can be changed with `g:niffler_fuzzy_char`

The beginning and end of the query are fuzzy by default but you can use `^` and
`$` to specify an exact match at either end:

* `^fizz` will match `fizzbazbuzz` but not `buzzfizzbaz`
* `buzz$` will match `fizzbazbuzz` but not `bazbuzzfizz`

Specify a command to be run on the open file by appending a ":<CMD>" to the end
of the search query.

* `iz*buz:45` will open a file `fizzbazbuzz` and jump to line 45
* `iz*buz:diffthis` will open a file `fizzbazbuzz` and add the file to the diff windows

Niffler has several different modes:

| Command           | Description                                                       |
| ----------------- | ------------------------------------------------------------------|
| `Niffler`         | Fuzzy file search                                                 |
| `NifflerMRU`      | Fuzzy file search on MRU cache                                    |
| `NifflerBuffer`   | Fuzzy file search on buffer list                                  |
| `NifflerTags`     | Fuzzy file search on ctags list                                   |
| `NifflerTselect`  | Fuzzy file search on matching tags                                |
| `NifflerGlobal`   | Fuzzy file search on GNU global file list                         |

The `Niffler` command takes any number of optional arguments and has the following structure:

`Niffler [-vcs] [-new] [-all] [DIRECTORY]`

* -vcs: search from git root directory of current file
* -new: search for directory and enter new file name
* -all: search all files/directories, including hidden and any ignored files
* Directory to search from

The size of the MRU cache (default 50) can be configured with the variable
`g:niffler_mru_max_history`.


#### Ctags Filtering

- The `NifflerTags` command can optionally take a % as argument to only search
for tags in the current file.

- The `NifflerTselect` command can be used to replace the built-in `:tselect`
command and filter a list of matching tags.
    - `nnoremap <silent> g] :NifflerTselect<CR>`


### Key Mappings

| Key                       | Action                                    |
| ------------------------- | ------------------------------------------|
| `<C-K>`, `<C-P>`          | Move up one line in the candidate list    |
| `<C-J>`, `<C-N>`          | Move down one line in the candidate list  |
| `<C-A>`                   | Scroll to the beginning of the line       |
| `<C-E>`                   | Scroll to the end of the line             |
| `<C-R>`                   | Insert the contents of a register         |
| `<CR>`                    | Open selection in current window          |
| `<C-S>`                   | Open selection in new horizontal split    |
| `<C-V>`                   | Open selection in new vertical split      |
| `<C-T>`                   | Open selection in new tab window          |
| `<Esc>`, `<C-[>`, `<C-C>` | Quit Niffler                              |


### Configuration

- `g:niffler_ignore_extensions`
    - List of file extensions to exclude from Niffler results
- `g:niffler_ignore_dirs`
    - List of directories to exclude from Niffler results
    - Helpful for large directories that could slow Niffler down


Requirements
------------

Niffler currently requires the `find`, `grep`, and `touch` utilities for full
support.  Niffler is not tested on Windows and its current level of support is
unknown.

**Note**: If you use OS X, I highly recommend aliasing the BSD findutils with
their GNU counterparts, which I've found can speed up find queries by a factor
of 2.  This might cause some problems with the `locate` command so use at your
own discretion but you can install the GNU versions with the command:

`brew install findutils --with-default-names`


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

Copyright (c) 2015 Pierre-Guy Douyon.  Distributed under the MIT License.


[FZF]: https://github.com/junegunn/fzf
[Pathogen]: https://github.com/tpope/vim-pathogen
[Vundle]: https://github.com/gmarik/Vundle.vim
[NeoBundle]: https://github.com/Shougo/neobundle.vim
[Vim-Plug]: https://github.com/junegunn/vim-plug
