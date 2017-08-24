let s:save_cpo = &cpoptions
set cpoptions&vim


function! niffler#tag#tag_stack(...)
    let tabnr = a:0 ? a:1 : tabpagenr()
    let winnr = a:0 ? a:2 : winnr()
    let tag_stack = gettabwinvar(tabnr, winnr, "niffler_tag_stack", [])
    if empty(tag_stack)
        call settabwinvar(tabnr, winnr, "niffler_tag_stack", tag_stack)
    endif
    return tag_stack
endfunction


function! niffler#tag#inherit_tag_stack(tabnr, winnr)
    call setwinvar(0, "niffler_tag_stack", niffler#tag#tag_stack(a:tabnr, a:winnr))
endfunction


function! niffler#tag#jump()
    try
        call niffler#tag#push()
        execute "normal! \<C-]>"
    catch
        call niffler#utils#echo_error(v:errmsg)
    endtry
endfunction


function! niffler#tag#push()
    call add(niffler#tag#tag_stack(), {'bufnr': bufnr("%"), 'curpos': getcurpos()})
endfunction


function! niffler#tag#pop()
    let tag_stack = niffler#tag#tag_stack()
    if empty(tag_stack)
        call niffler#utils#echo_error("[Niffler]: at bottom of tag stack")
    else
        let tag_stack_entry = get(tag_stack, -1)
        try
            call niffler#utils#try_visit(tag_stack_entry.bufnr)
            call setpos(".", tag_stack_entry.curpos)
            call remove(tag_stack, -1)
        catch
            call niffler#utils#echo_error(substitute(v:exception, '^[^:]*:', '', ''))
        endtry
    endif
endfunction


let &cpoptions = s:save_cpo
unlet s:save_cpo
