" Niffler filetype plugin file
if exists("b:did_ftplugin")
  finish
endif
let b:did_ftplugin = 1

let s:save_cpo = &cpoptions
set cpoptions&vim

setlocal buftype=nofile
setlocal bufhidden=delete
setlocal noreadonly noswapfile

setlocal nofoldenable
setlocal nowrap
setlocal nolist
setlocal nospell
setlocal nonumber
setlocal nocursorcolumn

setlocal foldcolumn=0

if exists("&relativenumber")
    setlocal norelativenumber
endif
if exists("&colorcolumn")
    setlocal colorcolumn=""
endif
if has("conceal")
    setlocal conceallevel=3 concealcursor=nc
endif

let &cpoptions = s:save_cpo
unlet s:save_cpo
