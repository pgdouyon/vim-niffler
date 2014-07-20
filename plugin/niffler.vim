if exists("g:loaded_niffler")
    finish
endif
let g:loaded_niffler = 1

let s:save_cpo = &cpoptions
set cpoptions&vim

let s:prompt = "> "
let s:match_id = 0
let s:vglobal_filter_limit = 1000

let s:script_folder = expand("<sfile>:p:h")
let s:mru_cache_file = s:script_folder."/niffler_mru_list.txt"
if !filereadable(s:mru_cache_file)
    call system("touch ".s:mru_cache_file)
endif
let s:mru_list = readfile(s:mru_cache_file)

if !exists("g:niffler_mru_max_history")
    let g:niffler_mru_max_history = 500
endif

if !exists("g:niffler_fuzzy_char")
    let g:niffler_fuzzy_char = ";"
endif

function! s:Niffler(vcs_root, new_file,  ...)
    if !executable("find")
        echoerr "Niffler: `find` command not installed. Unable to build list of files."
        return
    endif
    let old_wd = getcwd()
    if a:vcs_root
        let vcs = finddir(".git", expand("%:p:h").";")
        let dir = matchstr(vcs, '\v.*\ze\/\.git')
    else
        let dir = (a:0 ? a:1 : "~")
    endif
    execute "lchdir! ".dir

    let find_args = ""
    if a:new_file
        let find_args .= '-type d -print '
    else
        let find_args .= '\( -type f -o -type l \) -print '
    endif
    let file_list = s:FindFiles(find_args)
    call s:OpenNifflerBuffer()
    call s:SetNifflerText(file_list)
    call s:SetNifflerAutocmds()
    call s:SetNifflerOptions()
    call s:SetNifflerMappings()
    call s:HighlightFirstSelection()
    let b:niffler_old_wd = old_wd
    let b:niffler_candidate_list = file_list
    let b:niffler_refresh_candidates = 0
    let b:niffler_force_internal = 0
    let b:niffler_last_prompt = ""
    let b:niffler_prompt = ""
    let b:niffler_find_args = find_args
    let b:niffler_new_file = a:new_file
endfunction


function! s:NifflerMRU()
    call s:OpenNifflerBuffer()
    call s:PruneMruList()

    call reverse(s:mru_list)
    call s:SetNifflerText(s:mru_list)
    call reverse(s:mru_list)

    call s:SetNifflerAutocmds()
    call s:SetNifflerOptions()
    call s:SetNifflerMappings()
    call s:HighlightFirstSelection()
    let b:niffler_old_wd = getcwd()
    let b:niffler_candidate_list = s:mru_list
    let b:niffler_refresh_candidates = 1
    let b:niffler_force_internal = 1
    let b:niffler_last_prompt = ""
    let b:niffler_prompt = ""
    let b:niffler_find_args = ""
    let b:niffler_new_file = 0
endfunction


function! s:FindFiles(args)
    let hidden_ignore = "-path '*/\.*' -prune -o "
    let find_cmd = "find * ".hidden_ignore.a:args."2>/dev/null"
    let find_result = system(find_cmd)
    let files = split(find_result, "\n")
    return files
endfunction


function! s:OpenNifflerBuffer()
    keepjumps edit __Niffler__
endfunction


function! s:SetNifflerText(file_list)
    call setline(1, s:prompt)
    call append(1, a:file_list)
    call cursor(1,3)
    startinsert!
endfunction


function! s:SetNifflerAutocmds()
    autocmd CursorMovedI <buffer> call <SID>OnCursorMovedI()
    autocmd CursorMoved <buffer> call <SID>OnCursorMoved()
    autocmd InsertEnter <buffer> call <SID>OnInsertEnter()
    autocmd BufLeave <buffer> call <SID>OnBufLeave()
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
    call s:RefreshCandidateList()
    call s:FilterCandidateList(b:niffler_force_internal)
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


function! s:RefreshCandidateList()
    let cur_prompt = getline(1)
    let refresh = b:niffler_refresh_candidates && !matchstr(cur_prompt, b:niffler_last_prompt)
    if refresh
        execute 'silent! 2,$delete'
        call append(1, b:niffler_candidate_list)
    endif
endfunction


function! s:FilterCandidateList(internal)
    let internal_filter = a:internal || line("$") < s:vglobal_filter_limit
    let prompt_line = getline(1)
    let prompt = matchstr(prompt_line, '\V'.s:prompt.'\s\*\zs\S\+')
    if strlen(prompt) <= 0
        return
    endif
    if internal_filter
        let b:niffler_refresh_candidates = 1
        let bol = (prompt =~# '^\^') ? '' : '.\{-}'
        let eol = (prompt =~# '\$$') ? '' : '.\{-}'
        let smart_case = (prompt =~# '\u') ? '\C' : '\c'
        let filter_regex = substitute(prompt, '\.', '\\.', 'g')
        let filter_regex = substitute(filter_regex, '\V'.g:niffler_fuzzy_char, '.\\{-}', 'g')
        execute 'silent! 2,$vglobal/\m'.smart_case.bol.filter_regex.eol.'/delete'
    else
        let b:niffler_refresh_candidates = 0
        let bol = (prompt =~# '^\^') ? '' : '*'
        let eol = (prompt =~# '\$$') ? '' : '*'
        let smart_case = (prompt =~# '\u') ? "-path " : "-iwholename "
        let filter_regex = substitute(prompt, '^\^', '', '')
        let filter_regex = substitute(filter_regex, '\$$', '', '')
        let filter_regex = substitute(filter_regex, '\.', '\\.', 'g')
        let filter_regex = substitute(filter_regex, '\V'.g:niffler_fuzzy_char, '*', 'g')

        let hidden_ignore = "-path '*/\.*' -prune -o "
        let search_pat = smart_case."'".bol.filter_regex.eol."'"
        let filter_args = hidden_ignore . search_pat . " -a " . b:niffler_find_args
        let filter_cmd = "find * ".filter_args." 2>/dev/null"
        let filter_result = system(filter_cmd)
        let files = split(filter_result, "\n")
        execute '1,$delete'
        call append(0, prompt_line)
        call append(1, files)
    endif
endfunction


function! s:OnCursorMoved()
    let line = line(".")
    if line == 1
        let line = 2
    endif
    call s:HighlightSelectionLine()
    silent! call matchdelete(s:match_id)
    let s:match_id = matchadd("nifflerSelectionLine", '\%'.line.'l.*')
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
    silent! setlocal foldcolumn=0
    silent! setlocal colorcolumn=0
    silent! setlocal buflisted noswapfile nospell nofoldenable noreadonly nowrap
    silent! setlocal nocursorline nocursorcolumn nonumber norelativenumber
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


function! s:HighlightFirstSelection()
    call s:HighlightSelectionLine()
    let s:match_id = matchadd("nifflerSelectionLine", '\%2l.*')
endfunction


function! s:OpenSelection(cmd)
    let is_prompt_line = (line(".") == 1)
    if is_prompt_line
        call cursor(2, 1)
    endif

    let file = getline(".")
    let file = substitute(file, '\v\_^\s*', '', '')
    let file = substitute(file, '\v\s*$', '', '')
    if b:niffler_new_file
        let new_file = input("New file name: ")
        let file = l:file."/".new_file
        if new_file =~ "/"
            call mkdir(matchstr(getcwd()."/".file, '.*\ze\/'), "p")
        endif
        call system("touch ".file)
    endif
    let old_wd = b:niffler_old_wd
    execute "keepalt keepjumps ".a:cmd." "file
    execute "lchdir! ".old_wd
endfunction


function! s:HighlightSelectionLine()
    let color = (&background ==? "light") ? "cyan" : "darkcyan"
    execute "highlight nifflerSelectionLine ctermbg=".color." guibg=".color
endfunction


function! s:OnBufLeave()
    silent! call matchdelete(s:match_id)
endfunction


function! s:UpdateMruList(fname)
    let scratch = (&l:buftype ==# "nofile")
    let quickfix = (&l:buftype ==# "quickfix")
    let helpfile = (&l:buftype ==# "help")
    let unlisted = (&l:buflisted == 0)
    if !scratch && !quickfix && !helpfile && !unlisted
        call add(s:mru_list, a:fname)
    endif
endfunction


function! s:PruneMruList()
    let size = len(s:mru_list)
    let unique_mru_files = {}
    for i in range(size - 1, 0, -1)
        let file = s:mru_list[i]
        if has_key(unique_mru_files, file)
            call remove(s:mru_list, i)
        else
            let unique_mru_files[file] = 0
        endif
    endfor

    let size = len(s:mru_list)
    if size > g:niffler_mru_max_history
        let slice_index = size - g:niffler_mru_max_history
        call remove(s:mru_list, 0, slice_index - 1)
    endif
endfunction


function! s:WriteMruCacheFile()
    call s:PruneMruList()
    call writefile(s:mru_list, s:mru_cache_file)
endfunction

command! -nargs=? -complete=dir Niffler call <SID>Niffler(0, 0, <f-args>)
command! -nargs=? -complete=dir NifflerVCS call <SID>Niffler(1, 0, <f-args>)
command! -nargs=? -complete=dir NifflerNew call <SID>Niffler(0, 1, <f-args>)
command! -nargs=? -complete=dir NifflerNewVCS call <SID>Niffler(1, 1, <f-args>)
command! -nargs=0 NifflerMRU call <SID>NifflerMRU()

augroup niffler
    autocmd BufLeave * call <SID>UpdateMruList(expand("%:p"))
    autocmd CursorHold * call <SID>PruneMruList()
    autocmd VimLeave * call <SID>WriteMruCacheFile()
augroup END

let &cpoptions = s:save_cpo
unlet s:save_cpo
