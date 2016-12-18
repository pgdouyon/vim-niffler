let s:save_cpo = &cpoptions
set cpoptions&vim


function! niffler#utils#echo_error(error_message)
    echohl ErrorMsg | echomsg a:error_message | echohl None
endfunction


function! niffler#utils#try_visit(bufnr, ...) abort
    if a:bufnr != bufnr("%") && bufexists(a:bufnr)
        let noautocmd = bufloaded(a:bufnr) ? "noautocmd" : ""
        execute "silent" noautocmd join(a:000, " ") "keepjumps buffer" a:bufnr
        call setbufvar(a:bufnr, 'buflisted', 1)
    endif
endfunction


let &cpoptions = s:save_cpo
unlet s:save_cpo
