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

call s:set_default("g:niffler_mru_max_history", "300")
call s:set_default("g:niffler_mru_ignore_buftypes", "[]")
call s:set_default("g:niffler_mru_ignore_filetypes", "[]")
call s:set_default("g:niffler_fuzzy_char", '"*"')
call s:set_default("g:niffler_ignore_extensions", "[]")
call s:set_default("g:niffler_ignore_dirs", "[]")
call s:set_default("g:niffler_user_command", '""')
call s:set_default("g:niffler_conceal_tags_fullpath", '1')
call s:set_default("g:niffler_prompt", '"> "')
call s:set_default("g:niffler_marked_indicator", '"* "')
call s:set_default("g:niffler_tag_mappings", '0')

highlight default link NifflerCursorLine Error
highlight default link NifflerMarkedLine Todo


" ======================================================================
" Commands
" ======================================================================

command! -nargs=* -complete=dir Niffler call niffler#niffler(<q-args>)
command! -nargs=0 NifflerMRU call niffler#mru()
command! -nargs=0 NifflerBuffer call niffler#buffer()
command! -nargs=? NifflerTags call niffler#tags(<q-args> ==# "%")
command! -nargs=? NifflerTselect call niffler#tselect(<q-args>)
command! -nargs=? NifflerTjump call niffler#tjump(<q-args>)


" ======================================================================
" Mappings
" ======================================================================

nnoremap <silent> <Plug>NifflerTagJump :<C-U>call niffler#tag#jump()<CR>
nnoremap <silent> <Plug>NifflerTagPop  :<C-U>call niffler#tag#pop()<CR>
nnoremap <silent> <Plug>NifflerTselect :<C-U>NifflerTselect<CR>
nnoremap <silent> <Plug>NifflerTjump   :<C-U>NifflerTjump<CR>
if g:niffler_tag_mappings
    nmap <C-]>  <Plug>NifflerTagJump
    nmap <C-T>  <Plug>NifflerTagPop
    nmap g]     <Plug>NifflerTselect
    nmap g<C-]> <Plug>NifflerTjump
endif


" ======================================================================
" Autocommands
" ======================================================================

augroup niffler
    autocmd!
    autocmd BufLeave,VimLeavePre * call niffler#mru#add(expand("%:p"))
    autocmd CursorHold,VimLeave * call niffler#mru#save_file()
augroup END

let &cpoptions = s:save_cpo
unlet s:save_cpo
