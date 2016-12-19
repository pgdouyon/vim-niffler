let s:save_cpo = &cpoptions
set cpoptions&vim

let s:autoload_folder = expand("<sfile>:p:h:h")
let s:mru_cache_file = s:autoload_folder."/niffler_mru_list.txt"
if !filereadable(s:mru_cache_file)
    call system("touch ".s:mru_cache_file)
endif
let s:mru_list = readfile(s:mru_cache_file)

" ======================================================================
" MRU Handlers
" ======================================================================
function! niffler#mru#list()
    return s:mru_list
endfunction

function! niffler#mru#add(fname)
    let ignore_buftypes = ['nofile', 'quickfix', 'help', 'terminal']
    let ignore_filetypes = ['gitcommit']
    call extend(ignore_buftypes, g:niffler_mru_ignore_buftypes)
    call extend(ignore_filetypes, g:niffler_mru_ignore_filetypes)

    let ignore_buftype = (index(ignore_buftypes, &l:buftype) != -1)
    let ignore_filetype = (index(ignore_filetypes, &l:filetype) != -1)
    let unlisted = (&l:buflisted == 0)
    let temp = (a:fname =~# '/te\?mp/')
    let vcs_file = (a:fname =~# '/\.\%(git\|svn\|hg\)/')
    let empty_fname = empty(a:fname)
    if !(ignore_buftype || ignore_filetype || unlisted || temp || vcs_file || empty_fname)
        call add(s:mru_list, a:fname)
    endif
endfunction


function! niffler#mru#update()
    let size = len(s:mru_list)
    let unique_mru_files = {}
    for i in range(size - 1, 0, -1)
        let file = s:mru_list[i]
        if has_key(unique_mru_files, file)
            call remove(s:mru_list, i)
        elseif !empty(file)
            let unique_mru_files[file] = 0
        endif
    endfor

    let size = len(s:mru_list)
    if size > g:niffler_mru_max_history
        let slice_index = size - g:niffler_mru_max_history
        call remove(s:mru_list, 0, slice_index - 1)
    endif
endfunction


function! niffler#mru#save_file()
    call niffler#mru#update()
    call writefile(s:mru_list, s:mru_cache_file)
endfunction

let &cpoptions = s:save_cpo
unlet s:save_cpo
