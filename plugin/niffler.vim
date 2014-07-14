if exists("g:loaded_niffler")
    finish
endif
let g:loaded_niffler = 1

let s:save_cpo = &cpoptions
set cpoptions&vim

let s:prompt = "> "

function! s:Niffler(...)
    let old_wd = getcwd()
    let dir = (a:0 ? a:1 : "~")
    execute "lchdir! ".dir
    let file_list = s:FindFiles()
    call s:OpenNifflerBuffer(file_list)
    call s:SetNifflerOptions()
    call s:SetNifflerMappings()
    call s:SetNifflerAutocmds()
    let b:niffler_file_list = file_list
    let b:niffler_old_wd = old_wd
    let b:niffler_last_prompt = ""
    let b:niffler_prompt = ""
endfunction


function! s:FindFiles()
    if !executable("find")
        echoerr "Niffler: `find` command not installed. Unable to build list of files."
        return []
    endif
    let find_cmd = 'ag -g ""'
    let find_result = system(find_cmd)
    let files = split(find_result, "\n")
    return files
endfunction


function! s:OpenNifflerBuffer(file_list)
    keepjumps edit __Niffler__

    call setline(1, s:prompt)
    call append(1, a:file_list)
    call cursor(1,3)
    startinsert!
endfunction


function! s:SetNifflerOptions()
    set filetype=niffler
    setlocal buftype=nofile
    setlocal bufhidden=wipe
    setlocal foldcolumn=0
    setlocal buflisted noswapfile nospell nofoldenable noreadonly nonumber nowrap
    if exists("+cursorcolumn")
        setlocal nocursorcolumn
    endif
    if exists("+colorcolumn")
        setlocal colorcolumn=0
    endif
    if exists("+relativenumber")
        setlocal norelativenumber
    endif
endfunction


function! s:SetNifflerMappings()
    let ins_del_cmds = ["<BS>", "<Del>", "<C-h>", "<C-w>", "<C-u>"]
    for cmd in ins_del_cmds
        execute printf("inoremap <buffer> %s %s<C-o>:call <SID>RedrawPrompt()<CR>", cmd, cmd)
    endfor

    inoremap <buffer> <C-J> <Space>
    inoremap <buffer> <C-M> <Esc>:call <SID>OpenSelection()<CR>
    inoremap <buffer> <CR> <Esc>:call <SID>OpenSelection()<CR>

    nnoremap <buffer> o :<C-u>call <SID>OpenSelection()<CR>
    nnoremap <buffer> O :<C-u>call <SID>OpenSelection()<CR>
    nnoremap <buffer> <CR> :<C-u>call <SID>OpenSelection()<CR>
endfunction


function! s:OpenSelection()
    let is_prompt_line = (line(".") == 1)
    if is_prompt_line
        call cursor(2, 1)
    endif
    let file = getline(".")
    let file = substitute(file, '\v\_^\s*', '', '')
    let file = substitute(file, '\v\s*$', '', '')
    let dir = getcwd()
    execute "lchdir! ".b:niffler_old_wd
    execute "keepalt keepjumps edit ".dir."/".file
endfunction


function! s:SetNifflerAutocmds()
    autocmd CursorMovedI <buffer> call <SID>OnCursorMovedI()
    autocmd InsertEnter <buffer> call <SID>OnInsertEnter()
endfunction


function! s:OnCursorMovedI()
    let is_prompt_line = (line(".") == 1)
    let cursor_out_of_bounds = col(".") < 3
    if !is_prompt_line
        call feedkeys("\e", "nt")
    elseif cursor_out_of_bounds
        call cursor(1, 3)
    endif
    let prompt_changed = (b:niffler_prompt !=# getline(1))
    if prompt_changed
        let b:niffler_last_prompt = b:niffler_prompt
        let b:niffler_prompt = getline(1)
        call s:RedrawScreen()
    endif
endfunction


function! s:RedrawScreen()
    call s:RedrawPrompt()
    call s:RedrawCandidateList()
    call s:FilterCandidateList()
    call cursor(1,3)
    startinsert!
endfunction


function! s:RedrawPrompt()
    let prompt_line = getline(1)
    if prompt_line !~ '\V\_^' . s:prompt
        let re = '\v\_^\s*\>\s*'
        let prompt_line = substitute(prompt_line, re, '', '')
        call setline(1, s:prompt . prompt_line)
    endif
endfunction


function! s:RedrawCandidateList()
    let last_prompt = '\V' . b:niffler_last_prompt
    let redraw_list = match(b:niffler_prompt, last_prompt)
    if redraw_list == -1
        execute '2,$delete'
        call append(1, b:niffler_file_list)
    endif
endfunction


function! s:FilterCandidateList()
    let prompt_line = getline(1)
    let prompt = matchstr(prompt_line, '\V'.s:prompt.'\s\*\zs\S\+')
    let fuzzy_filter = substitute(prompt, '\S', '[^&]{-}&', 'g')
    execute 'silent 2,$vglobal/\v'.fuzzy_filter.'/delete'
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

command! -nargs=? -complete=dir Niffler call<SID>Niffler(<f-args>)

let &cpoptions = s:save_cpo
unlet s:save_cpo
