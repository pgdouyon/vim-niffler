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


function! s:OpenNifflerBuffer(file_list)
    noautocmd keepalt keepjumps edit "__Niffler__"
    call s:SetNifflerOptions()
    call s:SetNifflerMappings()
    call s:SetNifflerAutocmds()

    let prompt = "> "
    call setline(1, prompt)
    call append(1, a:file_list)
endfunction


function! s:SetNifflerOptions()
    set filetype=niffler
    setlocal buftype=nofile
    setlocal bufhidden=wipe
    setlocal foldcolumn = 0
    setlocal buflisted noswapfile nospell nofoldenable noreadonly nonumber nowrap
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


function! s:SetNifflerMappings()
    let ins_del_cmds = ["<BS>", "<Del>", "<C-h>", "<C-w>", "<C-u>"]
    for cmd in ins_del_cmds
        execute printf("inoremap <buffer> %s %s<C-o>:call <SID>RedrawPrompt()<CR>", cmd)
    endfor

    inoremap <buffer> <C-J> <Space>
    inoremap <buffer> <C-M> <Esc>:call <SID>OpenSelection()<CR>
    inoremap <buffer> <CR> <Esc>:call <SID>OpenSelection()<CR>

    nnoremap <buffer> o :<C-u>call <SID>OpenSelection()<CR>
    nnoremap <buffer> O :<C-u>call <SID>OpenSelection()<CR>
    nnoremap <buffer> <CR> :<C-u>call <SID>OpenSelection()<CR>
endfunction


function! s:SetNifflerAutocmds()
    autocmd CursorMoved <buffer> call s:RedrawPrompt()
endfunction


function! s:RedrawPrompt()
    if line(".") == 1
        let prompt = "> "
        let line = getline(".")
        if line !~ '\V\_^' . prompt
            call append(0, prompt)
            " TODO - should also repopulate file list
        endif
    endif
endfunction

let &cpoptions = s:save_cpo
unlet s:save_cpo
