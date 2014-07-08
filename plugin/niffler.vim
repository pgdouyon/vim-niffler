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


function! s:OpenNifflerBuffer()
    noautocmd keepalt keepjumps edit "__Niffler__"
    set filetype=niffler
    setlocal buftype=nofile
    setlocal bufhidden=wipe
    setlocal buflisted
    setlocal noswapfile
    setlocal nospell
    setlocal nofoldenable
    setlocal noreadonly
    setlocal nonumber
    setlocal foldcolumn = 0
    if exists("+cursorcolumn")
        setlocal nocursorcolumn
    endif
    if exists("+colorcolumn")
        setlocal colorcolumn = 0
    endif
    if exists("+relativenumber")
        setlocal norelativenumber
    endif
endfunction

let &cpoptions = s:save_cpo
unlet s:save_cpo
