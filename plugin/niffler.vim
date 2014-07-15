if exists("g:loaded_niffler")
    finish
endif
let g:loaded_niffler = 1

let s:save_cpo = &cpoptions
set cpoptions&vim

let s:prompt = "> "
if !exists("g:niffler_fuzzy_char")
    let g:niffler_fuzzy_char = ";"
endif

function! s:Niffler(vcs_root, ...)
    let old_wd = getcwd()
    if a:vcs_root
        let vcs = finddir(".git", expand("%:p:h").";")
        let dir = matchstr(vcs, '\v.*\ze\/\.git')
    else
        let dir = (a:0 ? a:1 : "~")
    endif
    execute "lchdir! ".dir

    let file_list = s:FindFiles()
    call s:OpenNifflerBuffer(file_list)
    call s:SetNifflerAutocmds()
    call s:SetNifflerOptions()
    call s:SetNifflerMappings()
    let b:niffler_old_wd = old_wd
    let b:niffler_prompt = ""
endfunction


function! s:FindFiles()
    if !executable("find")
        echoerr "Niffler: `find` command not installed. Unable to build list of files."
        return []
    endif
    let find_cmd = "find * -path '*/\.*' -prune -o -type f -print -o -type l -print 2>/dev/null"
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
        let b:niffler_prompt = getline(1)
        call s:RedrawScreen()
    endif
endfunction


function! s:RedrawScreen()
    call s:RedrawPrompt()
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


function! s:FilterCandidateList()
    let prompt_line = getline(1)
    let prompt = matchstr(prompt_line, '\V'.s:prompt.'\s\*\zs\S\+')
    if strlen(prompt) > 0
        let bol = (prompt =~# '^\^') ? '' : '*'
        let eol = (prompt =~# '\$$') ? '' : '*'
        let smart_case = (prompt =~# '\u') ? "-path " : "-iwholename "
        let filter_regex = substitute(prompt, '\V'.g:niffler_fuzzy_char, '*', 'g')
        let filter_regex = substitute(filter_regex, '^\^', '', '')
        let filter_regex = substitute(filter_regex, '\$$', '', '')
        let filter_regex = substitute(filter_regex, '\.', '\\.', 'g')

        let search_pat = smart_case."'".bol.filter_regex.eol."'"
        let filter_cmd = "find * -path '*/\.*' -prune -o ".search_pat." -print 2>/dev/null"
        let filter_result = system(filter_cmd)
        let files = split(filter_result, "\n")
        execute '1,$delete'
        call append(0, prompt_line)
        call append(1, files)
    endif
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

    inoremap <buffer> <C-J> <Down>
    inoremap <buffer> <C-K> <Up>
    inoremap <buffer> <C-M> <Esc>:call <SID>OpenSelection("edit")<CR>
    inoremap <buffer> <CR> <Esc>:call <SID>OpenSelection("edit")<CR>
    inoremap <buffer> <C-T> <Esc>:call <SID>OpenSelection("tabedit")<CR>
    inoremap <buffer> <C-V> <Esc>:call <SID>OpenSelection("vsplit")<CR>
    inoremap <buffer> <C-S> <Esc>:call <SID>OpenSelection("split")<CR>

    nnoremap <buffer> <C-J> <Down>
    nnoremap <buffer> <C-K> <Up>
    nnoremap <buffer> o :<C-u>call <SID>OpenSelection("edit")<CR>
    nnoremap <buffer> O :<C-u>call <SID>OpenSelection("edit")<CR>
    nnoremap <buffer> <CR> :<C-u>call <SID>OpenSelection("edit")<CR>
    nnoremap <buffer> <C-T> <Esc>:call <SID>OpenSelection("tabedit")<CR>
    nnoremap <buffer> <C-V> <Esc>:call <SID>OpenSelection("vsplit")<CR>
    nnoremap <buffer> <C-S> <Esc>:call <SID>OpenSelection("split")<CR>
endfunction


function! s:OpenSelection(cmd)
    let is_prompt_line = (line(".") == 1)
    if is_prompt_line
        call cursor(2, 1)
    endif

    let file = getline(".")
    let file = substitute(file, '\v\_^\s*', '', '')
    let file = substitute(file, '\v\s*$', '', '')
    let dir = getcwd()
    execute "lchdir! ".b:niffler_old_wd
    execute "keepalt keepjumps ".a:cmd." ".dir."/".file
endfunction

command! -nargs=? -complete=dir Niffler call<SID>Niffler(0, <f-args>)
command! -nargs=? -complete=dir NifflerVCS call<SID>Niffler(1, <f-args>)

let &cpoptions = s:save_cpo
unlet s:save_cpo
