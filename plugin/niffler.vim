if exists("g:loaded_niffler")
    finish
endif
let g:loaded_niffler = 1

let s:save_cpo = &cpoptions
set cpoptions&vim

let s:find_cmd = "find * -path '*/\.*' -prune -o -type f -print -o -type l -print 2> /dev/null"

function! s:FindFiles()
    if !executable("find")
        echoerr "Niffler: `find` command not installed. Unable to build list of files."
    endif
    let find_result = system(s:find_cmd)
    let files = split(find_result, "\n")
    return files
endfunction

let &cpoptions = s:save_cpo
unlet s:save_cpo
