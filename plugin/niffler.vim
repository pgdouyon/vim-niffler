"==============================================================================
"File:        niffler.vim
"Description: Fuzzy file finder for Vim.  Supported modes are fuzzy file find by
"             directory, fuzzy file find by VCS root directory, MRU fuzzy file
"             find, and new file creation.
"Maintainer:  Pierre-Guy Douyon <pgdouyon@alum.mit.edu>
"Version:     1.0.0
"Last Change: 2014-07-20
"License:     MIT <../LICENSE>
"==============================================================================

" ======================================================================
" Configuration and Defaults
" ======================================================================

if exists("g:loaded_niffler")
    finish
endif
let g:loaded_niffler = 1

let s:save_cpo = &cpoptions
set cpoptions&vim

let s:prompt = "> "
let s:match_id = 0

let s:script_folder = expand("<sfile>:p:h")
let s:mru_cache_file = s:script_folder."/niffler_mru_list.txt"
if !filereadable(s:mru_cache_file)
    call system("touch ".s:mru_cache_file)
endif
let s:mru_list = readfile(s:mru_cache_file)

let s:function_map = {
    \"\<BS>"  : function("<SID>Backspace"),
    \"\<C-H>" : function("<SID>Backspace"),
    \"\<C-W>" : function("<SID>BackwardKillWord"),
    \"\<C-U>" : function("<SID>BackwardKillLine"),
    \"\<C-J>" : function("<SID>MoveNextLine"),
    \"\<C-K>" : function("<SID>MovePrevLine"),
    \"\<CR>"  : function("<SID>OpenCurrentWindow"),
    \"\<C-S>" : function("<SID>OpenSplitWindow"),
    \"\<C-V>" : function("<SID>OpenVertSplit"),
    \"\<C-T>" : function("<SID>OpenTabWindow"),
    \"\<Esc>" : function("<SID>QuitNiffler"),
    \"\<C-G>" : function("<SID>QuitNiffler")
    \}

if !exists("g:niffler_mru_max_history")
    let g:niffler_mru_max_history = 500
endif

if !exists("g:niffler_fuzzy_char")
    let g:niffler_fuzzy_char = "*"
endif


" ======================================================================
" Plugin Code
" ======================================================================
function! s:Niffler(args)
    if !executable("find")
        echoerr "Niffler: `find` command not installed. Unable to build list of files."
        return
    endif
    let dir = matchstr(a:args, '\s\+\zs[^-].*$')
    let opts = matchstr(a:args, '\%(-\S\+\s*\)\+')
    let new = (opts =~# "-new")
    let vcs = (opts =~# "-vcs")
    let all = (opts =~# "-all")

    let save_wd = getcwd()
    call s:ChangeWorkingDirectory((!empty(dir) ? dir : "~"), vcs)

    let file_list = s:FindFiles(all, new)
    call s:NifflerSetup(file_list)

    let b:niffler_save_wd = save_wd
    let b:niffler_new_file = new
    let b:niffler_open_cmd = "edit"
    let b:niffler_split_cmd = "split"

    call s:KeypressEventLoop()
endfunction


function! s:NifflerMRU()
    call s:PruneMruList()
    let mru_list =  reverse(copy(s:mru_list))
    call s:NifflerSetup(mru_list)
    let b:niffler_save_wd = getcwd()
    let b:niffler_new_file = 0
    let b:niffler_open_cmd = "edit"
    let b:niffler_split_cmd = "split"

    call s:KeypressEventLoop()
endfunction


function! s:NifflerBuffer()
    redir => buffers | silent ls | redir END
    let buflist = map(split(buffers, "\n"), 'matchstr(v:val, ''"\zs[^"]\+\ze"'')')
    call s:NifflerSetup(buflist)
    let b:niffler_save_wd = getcwd()
    let b:niffler_new_file = 0
    let b:niffler_open_cmd = "buffer"
    let b:niffler_split_cmd = "sbuffer"

    call s:KeypressEventLoop()
endfunction


function! s:ChangeWorkingDirectory(default_dir, vcs_root)
    let dir = a:default_dir
    if a:vcs_root
        let vcs = finddir(".git", expand("%:p:h").";")
        let dir = fnamemodify(vcs, ":h")
    endif
    execute "lchdir! ".dir
endfunction


function! s:FindFiles(unrestricted, new_file)
    if a:unrestricted
        let find_args = "-path '*/\.git*' -prune -o "
    else
        let find_args = "-path '*/\.*' -prune -o "
    endif

    if a:new_file
        let find_args .= '-type d -print '
    else
        let find_args .= '\( -type f -o -type l \) -print '
    endif

    let find_cmd = "find * " . find_args . "2>/dev/null"
    let find_result = system(find_cmd)
    let files = split(find_result, "\n")
    return files
endfunction


function! s:NifflerSetup(candidates)
    if !executable("grep")
        throw "Niffler: `grep` command not installed.  Unable to filter candidate list."
        return
    endif
    call s:OpenNifflerBuffer()
    call s:SetNifflerOptions()
    call append(0, a:candidates[0:winheight(0)-1])
    $ delete _

    let b:niffler_candidate_list = a:candidates
    let b:niffler_candidate_string = join(a:candidates, "\n")
    let b:niffler_candidate_limit = winheight(0)
    let b:niffler_new_file = 0
    let b:niffler_isactive = 1
endfunction


function! s:OpenNifflerBuffer()
    let origin_buffer = bufname("%")
    keepalt keepjumps edit __Niffler__
    let b:niffler_origin_buffer = origin_buffer
endfunction


function! s:SetNifflerOptions()
    set filetype=niffler
    setlocal buftype=nofile
    setlocal bufhidden=wipe
    silent! setlocal foldcolumn=0
    silent! setlocal colorcolumn=0
    silent! setlocal buflisted noswapfile nospell nofoldenable noreadonly nowrap
    silent! setlocal nocursorcolumn nonumber norelativenumber
endfunction


function! s:KeypressEventLoop()
    call cursor(line("$"), 1)
    let prompt = ""
    redraw
    echon s:prompt
    while exists("b:niffler_isactive")
        let nr = getchar()
        let char = !type(nr) ? nr2char(nr) : nr
        if (char =~# '\p') && (type(nr) == 0)
            let prompt = s:UpdatePrompt(prompt, char)
        else
            let mock_fun = "strtrans"
            let prompt = call(get(s:function_map, char, mock_fun), [prompt])
        endif
    endwhile
endfunction


function! s:UpdatePrompt(prompt, char)
    let prompt = a:prompt . a:char
    let query = s:ParseQuery(prompt)
    call s:FilterCandidateList(query)
    redraw
    echon s:prompt prompt
    return prompt
endfunction


function! s:Backspace(prompt)
    let prompt = a:prompt[0:-2]
    let query = s:ParseQuery(prompt)
    let b:niffler_candidate_string = join(b:niffler_candidate_list, "\n")
    call s:FilterCandidateList(query)
    redraw
    echon s:prompt prompt
    return prompt
endfunction


function! s:BackwardKillWord(prompt)
    let prompt = matchstr(a:prompt, '.*\s\ze\S\+$')
    let query = s:ParseQuery(prompt)
    let b:niffler_candidate_string = join(b:niffler_candidate_list, "\n")
    call s:FilterCandidateList(query)
    redraw
    echon s:prompt prompt
    return prompt
endfunction


function! s:BackwardKillLine(prompt)
    let empty_prompt = ""
    let b:niffler_candidate_string = join(b:niffler_candidate_list, "\n")
    call s:FilterCandidateList(empty_prompt)
    redraw
    echon s:prompt
    return empty_prompt
endfunction


function! s:MoveNextLine(prompt)
    call cursor(line(".") + 1, col("."))
    set cursorline!
    set cursorline!
    redraw
    echon s:prompt a:prompt
    return a:prompt
endfunction


function! s:MovePrevLine(prompt)
    call cursor(line(".") - 1, col("."))
    set cursorline!
    set cursorline!
    redraw
    echon s:prompt a:prompt
    return a:prompt
endfunction


function! s:OpenCurrentWindow(prompt)
    call s:OpenSelection(a:prompt, b:niffler_open_cmd)
    return ""
endfunction


function! s:OpenSplitWindow(prompt)
    call s:OpenSelection(a:prompt, b:niffler_split_cmd)
    return ""
endfunction


function! s:OpenVertSplit(prompt)
    let vert_cmd = "vertical " . b:niffler_split_cmd
    call s:OpenSelection(a:prompt, vert_cmd)
    return ""
endfunction


function! s:OpenTabWindow(prompt)
    let tab_cmd = "tab " . b:niffler_split_cmd
    call s:OpenSelection(a:prompt, tab_cmd)
    return ""
endfunction


function! s:OpenSelection(prompt, open_cmd)
    let prompt = s:ParseQuery(a:prompt)
    let command = s:ParseCommand(a:prompt)
    let selection = getline(".")
    let save_wd = b:niffler_save_wd

    if b:niffler_new_file
        let new_file = input("New file name: ")
        let file = file."/".new_file
        if new_file =~ "/"
            call mkdir(matchstr(getcwd()."/".file, '.*\ze\/'), "p")
        endif
        call system("touch ".file)
    endif
    call s:QuitNiffler(prompt)
    execute a:open_cmd selection
    execute command
    execute "lchdir " . save_wd
endfunction


function! s:QuitNiffler(prompt)
    unlet b:niffler_isactive
    execute "keepalt keepjumps buffer ".b:niffler_origin_buffer
endfunction


" ======================================================================
" Handler Functions
" ======================================================================

function! s:FilterCandidateList(query)
    if empty(b:niffler_candidate_string)
        return
    endif
    let query = empty(a:query) ? g:niffler_fuzzy_char : a:query
    let special_chars = substitute('.*[]\', '\V'.g:niffler_fuzzy_char, '', '')
    let filter_regex = escape(query, special_chars)
    let filter_regex = substitute(filter_regex, '\V'.g:niffler_fuzzy_char, '.*', 'g')
    let search_patterns = split(filter_regex)
    let map_expr = '"grep -m '.b:niffler_candidate_limit.'".((v:val =~# "\\u") ? "" : " -i")." -e \"".v:val."\""'
    let grep_filter = join(map(search_patterns, map_expr), " | ")
    let candidates = system(grep_filter, b:niffler_candidate_string)
    let candidate_list = split(candidates, "\n")
    if len(candidate_list) < b:niffler_candidate_limit
        let b:niffler_candidate_string = candidates
    endif
    silent! 1,$ delete _
    call append(0, candidate_list[0:b:niffler_candidate_limit-1])
    $ delete _
endfunction


function! s:ParseQuery(prompt)
    let query = get(split(a:prompt, ":"), 0, "")
    return query
endfunction


function! s:ParseCommand(prompt)
    let command = get(split(a:prompt, ":"), 1, "")
    return command
endfunction


" ======================================================================
" MRU Handlers
" ======================================================================

function! s:UpdateMruList(fname)
    let scratch = (&l:buftype ==# "nofile")
    let quickfix = (&l:buftype ==# "quickfix")
    let helpfile = (&l:buftype ==# "help")
    let unlisted = (&l:buflisted == 0)
    let gitcommit = (&l:filetype ==# "gitcommit")
    if !scratch && !quickfix && !helpfile && !unlisted && !gitcommit
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
        elseif !empty(file)
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


" ======================================================================
" Commands
" ======================================================================

command! -nargs=* -complete=dir Niffler call <SID>Niffler(<q-args>)
command! -nargs=0 NifflerMRU call <SID>NifflerMRU()
command! -nargs=0 NifflerBuffer call <SID>NifflerBuffer()


" ======================================================================
" Autocommands
" ======================================================================

augroup niffler
    autocmd!
    autocmd BufReadPost * call <SID>UpdateMruList(expand("%:p"))
    autocmd CursorHold * call <SID>WriteMruCacheFile()
augroup END

let &cpoptions = s:save_cpo
unlet s:save_cpo
