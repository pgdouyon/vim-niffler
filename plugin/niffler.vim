"==============================================================================
"File:        niffler.vim
"Description: Lightweight, fuzzy file finder for Vim.
"Maintainer:  Pierre-Guy Douyon <pgdouyon@alum.mit.edu>
"License:     MIT <../LICENSE>
"==============================================================================

" ======================================================================
" Configuration and Defaults
" ======================================================================

if exists("g:loaded_niffler")
    finish
endif
let g:loaded_niffler = 1

let s:save_cpo = &cpoptions
set cpoptions&vim

" ======================================================================
" Global Config
" ======================================================================
function! s:set_default(variable, default)
    if !exists(a:variable)
        execute printf("let %s = %s", a:variable, a:default)
    endif
endfunction

call s:set_default("g:niffler_mru_max_history", "50")
call s:set_default("g:niffler_mru_ignore_buftypes", "[]")
call s:set_default("g:niffler_mru_ignore_filetypes", "[]")
call s:set_default("g:niffler_fuzzy_char", '"*"')
call s:set_default("g:niffler_ignore_extensions", "[]")
call s:set_default("g:niffler_ignore_dirs", "[]")

highlight default link NifflerCursorLine Error


" ======================================================================
" Commands
" ======================================================================

command! -nargs=* -complete=dir Niffler call niffler#niffler(<q-args>)
command! -nargs=* -complete=dir NifflerGlobal call niffler#global(<q-args>)
command! -nargs=0 NifflerMRU call niffler#mru()
command! -nargs=0 NifflerBuffer call niffler#buffer()
command! -nargs=? NifflerTags call niffler#tags(<q-args> ==# "%")
command! -nargs=? NifflerTselect call niffler#tselect(<q-args>)


" ======================================================================
" Autocommands
" ======================================================================

augroup niffler
    autocmd!
    autocmd BufLeave,VimLeavePre * call niffler#update_mru_list(expand("%:p"))
    autocmd CursorHold,VimLeave * call niffler#write_mru_cache_file()
augroup END

let &cpoptions = s:save_cpo
unlet s:save_cpo
