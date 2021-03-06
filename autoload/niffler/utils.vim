let s:save_cpo = &cpoptions
set cpoptions&vim


function! niffler#utils#empty(value)
    return empty(a:value) || (type(a:value) == type("") && match(a:value, '\S') < 0)
endfunction


function! niffler#utils#echo_error(error_message)
    echohl ErrorMsg | echomsg a:error_message | echohl None
endfunction


function! niffler#utils#redir(command)
    redir => output
    try
        execute "silent" a:command
    catch
        let exception = substitute(v:exception, '^[^:]*:', '', '')
    endtry
    redir END

    if !exists("exception")
        return output
    endif
    throw exception
endfunction


function! niffler#utils#try_visit(bufnr, ...) abort
    if a:bufnr != bufnr("%") && bufexists(a:bufnr)
        execute "silent" join(a:000, " ") "keepjumps buffer" a:bufnr
        call setbufvar(a:bufnr, 'buflisted', 1)
    endif
endfunction


let &cpoptions = s:save_cpo
unlet s:save_cpo
