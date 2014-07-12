if exists("g:loaded_niffler")
    finish
endif
let g:loaded_niffler = 1

let s:save_cpo = &cpoptions
set cpoptions&vim

let s:prompt = "> "
let s:find_cmd = "find * -path '*/\.*' -prune -o -type f -print -o -type l -print 2> /dev/null"

function! s:Niffler()
    let file_list = s:FindFiles()
    call s:OpenNifflerBuffer(file_list)
    call s:SetNifflerOptions()
    call s:SetNifflerMappings()
    call s:SetNifflerAutocmds()
endfunction


function! s:FindFiles()
    if !executable("find")
        echoerr "Niffler: `find` command not installed. Unable to build list of files."
    endif
    let find_result = system(s:find_cmd)
    let files = split(find_result, "\n")
    return files
endfunction


function! s:OpenNifflerBuffer(file_list)
    keepjumps edit "__Niffler__"

    let b:niffler_file_list = a:file_list
    call setline(1, s:prompt)
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
    autocmd CursorMovedI <buffer> call <SID>OnCursorMovedI()
    autocmd InsertEnter <buffer> call <SID>OnInsertEnter()
    autocmd TextChanged <buffer> call <SID>RedrawPrompt()
endfunction


function! s:OnCursorMovedI()
    let is_prompt_line = (line(".") == 1)
    let cursor_out_of_bounds = col(".") < 3
    if !is_prompt_line
        call feedkeys("\e", "nt")
    elseif cursor_out_of_bounds
        call cursor(1, 3)
    endif
    call s:FilterCandidateList()
endfunction


function! s:FilterCandidateList()
    let prompt_line = getline(1)
    let prompt = matchstr(prompt_line, '\V'.s:prompt.'\s\*\zs\S\+')
    let fuzzy_filter = substitute(prompt, '\S', '[^&]{-}&', 'g')
    execute '2,$delete'
    call append(1, b:niffler_file_list)
    execute '2,$vglobal/\v'.fuzzy_filter.'/delete'
endfunction


function! s:OnInsertEnter()
    let is_prompt_line = (line(".") == 1)
    let cursor_out_of_bounds = col(".") < 3
    if !is_prompt_line
        call feedkeys("\e", "nt")
    elseif cursor_out_of_bounds
        let v:char = "move cursor"
        call cursor(1, 3)
    endif
endfunction


function! s:RedrawPrompt()
    let line = getline(1)
    if line !~ '\V\_^' . s:prompt
        let re = '\v\_^\s*\>\s*'
        let line = substitute(line, re, '', '')
        call setline(1, s:prompt . line)
        " TODO - should also repopulate file list
    endif
endfunction


function! s:OpenSelection()
    let is_prompt_line = (line(".") == 1)
    if is_prompt_line
        call cursor(2, 1)
    endif
    let file = getline(".")
    let file = substitute(file, '\v\_^\s*', '', '')
    let file = substitute(file, '\v\s*$', '', '')
    " TODO prepend filename with directory arg to find
    execute "keepalt keepjumps edit " . file
endfunction

let &cpoptions = s:save_cpo
unlet s:save_cpo
