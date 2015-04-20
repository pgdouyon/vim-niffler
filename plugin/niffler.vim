"==============================================================================
"File:        niffler.vim
"Description: Lightweight, fuzzy file finder for Vim.
"Maintainer:  Pierre-Guy Douyon <pgdouyon@alum.mit.edu>
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

" ======================================================================
" Global Config
" ======================================================================
function! s:set_default(variable, default)
    if !exists(a:variable)
        execute printf("let %s = %s", a:variable, a:default)
    endif
endfunction

call s:set_default("g:niffler_mru_max_history", "30")
call s:set_default("g:niffler_mru_ignore_buftypes", "[]")
call s:set_default("g:niffler_mru_ignore_filetypes", "[]")
call s:set_default("g:niffler_fuzzy_char", '"*"')
call s:set_default("g:niffler_ignore_extensions", "[]")
call s:set_default("g:niffler_ignore_dirs", "[]")

highlight default link NifflerCursorLine Error


" ======================================================================
" Script Local Config
" ======================================================================
let s:prompt = "> "
let s:match_id = 0

let s:script_folder = expand("<sfile>:p:h")
let s:mru_cache_file = s:script_folder."/niffler_mru_list.txt"
if !filereadable(s:mru_cache_file)
    call system("touch ".s:mru_cache_file)
endif
let s:mru_list = readfile(s:mru_cache_file)


" ======================================================================
" Plugin Code
" ======================================================================
function! s:niffler(args)
    if !executable("find")
        echoerr "Niffler: `find` command not installed. Unable to build list of files."
        return
    endif
    let dir = matchstr(a:args, '\%(-\S\+\s*\)*\zs.*$')
    let opts = matchstr(a:args, '\%(-\S\+\s*\)\+')
    let new = (opts =~# "-new")
    let vcs = (opts =~# "-vcs")
    let all = (opts =~# "-all")

    let save_wd = getcwd()
    call s:change_working_directory((!empty(dir) ? dir : expand("$HOME")), vcs)

    let candidate_string = s:find_files(all, new)
    call s:niffler_setup(candidate_string)

    let b:niffler_save_wd = save_wd
    let b:niffler_new_file = new
    let b:niffler_open_cmd = "edit"
    let b:niffler_split_cmd = "split"

    call s:keypress_event_loop()
endfunction


function! s:niffler_mru()
    call s:prune_mru_list()
    call s:niffler_setup(join(s:mru_list, "\n"))
    let b:niffler_save_wd = getcwd()
    let b:niffler_open_cmd = "edit"
    let b:niffler_split_cmd = "split"

    call s:keypress_event_loop()
endfunction


function! s:niffler_buffer()
    redir => buffers | silent ls | redir END
    let buflist = map(split(buffers, "\n"), 'matchstr(v:val, ''"\zs[^"]\+\ze"'')')
    let buflist_string = join(buflist, "\n")
    call s:niffler_setup(buflist_string)
    let b:niffler_save_wd = getcwd()
    let b:niffler_open_cmd = "buffer"
    let b:niffler_split_cmd = "sbuffer"

    call s:keypress_event_loop()
endfunction


function! s:niffler_tags(use_current_buffer)
    if a:use_current_buffer
        let taglist = s:taglist_current_buffer()
    else
        let taglist = s:taglist()
    endif
    call s:niffler_setup(taglist)
    let b:niffler_save_wd = getcwd()
    let b:niffler_open_cmd = (a:use_current_buffer ? "silent tag" : "tjump")
    let b:niffler_split_cmd = (a:use_current_buffer ? "silent stag" : "stjump")

    call s:keypress_event_loop()
endfunction


function! s:taglist()
    let taglist = ""
    let tagfiles = tagfiles()
    for tagfile in tagfiles
        let tags_cmd = 'grep -v ^!_TAG_ %s | cut -f1 | sort -u'
        let tags = system(printf(tags_cmd, tagfile))
        let taglist .= tags
    endfor
    return taglist
endfunction


function! s:taglist_current_buffer()
    if executable("ctags")
        let current_buffer = expand("%:p")
        let taglist_cmd = 'ctags -f - %s | cut -f1 | sort -u'
        let taglist = system(printf(taglist_cmd, current_buffer))
    else
        throw "[Niffler] - Error: ctags executable not found.\nctags is required to run :NifflerTags %"
    endif
    return taglist
endfunction


function! s:niffler_global(args)
    if !executable("global")
        echoerr "Niffler: `global` command not found. Unable to build list of files."
        return
    endif
    let dir = matchstr(a:args, '\%(-\S\+\s*\)*\zs.*$')
    let opts = matchstr(a:args, '\%(-\S\+\s*\)\+')
    let new = (opts =~# "-new")

    let save_wd = getcwd()
    let global_root = s:get_global_root()
    call s:change_working_directory((!empty(dir) ? dir : global_root), 0)

    let candidate_string = system("global -P '.*'")
    call s:niffler_setup(candidate_string)

    let b:niffler_save_wd = save_wd
    let b:niffler_new_file = new
    let b:niffler_open_cmd = "edit"
    let b:niffler_split_cmd = "split"

    call s:keypress_event_loop()
endfunction


function! s:get_global_root()
    lchdir! %:h
    let global_root = system("global -p")
    lchdir! -
    return global_root
endfunction


function! s:change_working_directory(default_dir, vcs_root)
    let dir = a:default_dir
    if a:vcs_root
        let vcs = finddir(".git", expand("%:p:h").";")
        let dir = fnamemodify(vcs, ":h")
    endif
    execute "lchdir! ".dir
endfunction


function! s:find_files(unrestricted, new_file)
    let find_args = s:get_default_find_args()
    if a:unrestricted
        let find_args .= "\( -path '*/\.git*' -o -path '*/\.svn*' -o -path '*/\.hg*' \) -prune -o "
    else
        let find_args .= "-path '*/\.*' -prune -o "
    endif

    if a:new_file
        let find_args .= '-type d -print '
    else
        let find_args .= '\( -type f -o -type l \) -print '
    endif

    let find_cmd = "find * " . find_args . "2>/dev/null"
    let find_result = system(find_cmd)
    let filtered_files = s:filter_ignore_files(find_result)
    return filtered_files
endfunction


function! s:get_default_find_args()
    let default_args = ""
    if !empty(g:niffler_ignore_dirs)
        let generate_path_expr = '"-path \"*".substitute(v:val, "[^/]$", "\\0/", "")."*\""'
        let ignore_dirs = join(map(copy(g:niffler_ignore_dirs), generate_path_expr), " -o ")
        let default_args = '\( '.ignore_dirs.' \) -prune -o '
    endif
    return default_args
endfunction


function! s:filter_ignore_files(candidates)
    if empty(g:niffler_ignore_extensions)
        return a:candidates
    else
        let escape_period = 'escape(v:val, ".")'
        let ignore_files = join(map(copy(g:niffler_ignore_extensions), escape_period), '\|')
        let filter_ignore_files = 'grep -v -e "\('.ignore_files.'\)$"'
        let filtered_candidates = system(filter_ignore_files, a:candidates)
        return filtered_candidates
    endif
endfunction


function! s:niffler_setup(candidate_string)
    if !executable("grep")
        throw "Niffler: `grep` command not installed.  Unable to filter candidate list."
        return
    endif
    call s:open_niffler_buffer()
    call s:set_niffler_options()
    call s:set_niffler_cursorline()
    let b:niffler_candidates_original = a:candidate_string
    let b:niffler_candidates = a:candidate_string
    let b:niffler_candidate_limit = winheight(0)
    let b:niffler_new_file = 0
    let b:niffler_isactive = 1
    call s:display(split(a:candidate_string, "\n"))
endfunction


function! s:open_niffler_buffer()
    let origin_buffer = bufname("%")
    keepalt keepjumps edit __Niffler__
    let b:niffler_origin_buffer = origin_buffer
endfunction


function! s:set_niffler_options()
    set filetype=niffler
    setlocal buftype=nofile
    setlocal bufhidden=wipe
    silent! setlocal foldcolumn=0
    silent! setlocal colorcolumn=0
    silent! setlocal buflisted noswapfile nospell nofoldenable noreadonly nowrap
    silent! setlocal nocursorcolumn nonumber norelativenumber
endfunction


function! s:set_niffler_cursorline()
    let save_matches = filter(getmatches(), 'has_key(v:val, "pattern")')
    let b:niffler_save_matches = save_matches | call clearmatches()
    let b:niffler_highlight_group = matchadd("NifflerCursorLine", '^.*\%#.*$', 0)
endfunction


function! s:keypress_event_loop()
    call cursor(line("$"), 1)
    let prompt = ""
    redraw
    echon s:prompt
    while exists("b:niffler_isactive")
        let nr = getchar()
        let char = !type(nr) ? nr2char(nr) : nr
        if (char =~# '\p') && (type(nr) == 0)
            let prompt = s:update_prompt(prompt, char)
        else
            let mock_fun = "strtrans"
            let prompt = call(get(s:function_map, char, mock_fun), [prompt])
        endif
    endwhile
endfunction


function! s:update_prompt(prompt, char)
    let prompt = a:prompt . a:char
    let query = s:parse_query(prompt)
    call s:filter_candidate_list(query)
    redraw
    echon s:prompt prompt
    return prompt
endfunction


function! s:backspace(prompt)
    let prompt = a:prompt[0:-2]
    let query = s:parse_query(prompt)
    let b:niffler_candidates = b:niffler_candidates_original
    call s:filter_candidate_list(query)
    redraw
    echon s:prompt prompt
    return prompt
endfunction


function! s:backward_kill_word(prompt)
    let prompt = matchstr(a:prompt, '.\{-\}\ze\S\+\s*$')
    let query = s:parse_query(prompt)
    let b:niffler_candidates = b:niffler_candidates_original
    call s:filter_candidate_list(query)
    redraw
    echon s:prompt prompt
    return prompt
endfunction


function! s:backward_kill_line(prompt)
    let empty_prompt = ""
    let b:niffler_candidates = b:niffler_candidates_original
    call s:filter_candidate_list(empty_prompt)
    redraw
    echon s:prompt
    return empty_prompt
endfunction


function! s:move_next_line(prompt)
    let is_last_line = (line(".") == line("$"))
    let next_line = (is_last_line ? 1 : line(".") + 1)
    call cursor(next_line, col("."))
    redraw!
    echon s:prompt a:prompt
    return a:prompt
endfunction


function! s:move_prev_line(prompt)
    let is_first_line = (line(".") == 1)
    let prev_line = (is_first_line ? line("$") : line(".") - 1)
    call cursor(prev_line, col("."))
    redraw!
    echon s:prompt a:prompt
    return a:prompt
endfunction


function! s:open_current_window(prompt)
    call s:open_selection(a:prompt, b:niffler_open_cmd)
    return ""
endfunction


function! s:open_split_window(prompt)
    call s:open_selection(a:prompt, b:niffler_split_cmd)
    return ""
endfunction


function! s:open_vert_split(prompt)
    let vert_cmd = "vertical " . b:niffler_split_cmd
    call s:open_selection(a:prompt, vert_cmd)
    return ""
endfunction


function! s:open_tab_window(prompt)
    let tab_cmd = "tab " . b:niffler_split_cmd
    call s:open_selection(a:prompt, tab_cmd)
    return ""
endfunction


function! s:open_selection(prompt, open_cmd)
    let prompt = s:parse_query(a:prompt)
    let command = s:parse_command(a:prompt)
    let selection = substitute(getline("."), '\s*$', '', '')
    let niffler_wd = getcwd()
    let save_wd = b:niffler_save_wd

    if b:niffler_new_file
        let new_file = input("New file name: ")
        let selection = selection."/".new_file
        if new_file =~ "/"
            call mkdir(matchstr(getcwd()."/".selection, '.*\ze\/'), "p")
        endif
        call system("touch ".selection)
    endif
    call s:quit_niffler(prompt)
    execute "lchdir! " . niffler_wd
    execute a:open_cmd selection
    execute command
    execute "lchdir! " . save_wd
endfunction


function! s:quit_niffler(prompt)
    unlet b:niffler_isactive
    let save_wd = b:niffler_save_wd
    call matchdelete(b:niffler_highlight_group)
    call setmatches(b:niffler_save_matches)
    execute "keepalt keepjumps buffer ".b:niffler_origin_buffer
    execute "lchdir! " . save_wd
endfunction


function! s:paste_from_register(prompt)
    let register = getchar()
    if !type(register)
        let paste_text = getreg(nr2char(register))
        let prompt = a:prompt . paste_text
        let query = s:parse_query(prompt)
        call s:filter_candidate_list(query)
        redraw
        echon s:prompt prompt
        return prompt
    else
        return a:prompt
    endif
endfunction


let s:function_map = {
    \"\<BS>"  : function("<SID>backspace"),
    \"\<C-H>" : function("<SID>backspace"),
    \"\<C-W>" : function("<SID>backward_kill_word"),
    \"\<C-U>" : function("<SID>backward_kill_line"),
    \"\<C-J>" : function("<SID>move_next_line"),
    \"\<C-N>" : function("<SID>move_next_line"),
    \"\<C-K>" : function("<SID>move_prev_line"),
    \"\<C-P>" : function("<SID>move_prev_line"),
    \"\<CR>"  : function("<SID>open_current_window"),
    \"\<C-S>" : function("<SID>open_split_window"),
    \"\<C-V>" : function("<SID>open_vert_split"),
    \"\<C-T>" : function("<SID>open_tab_window"),
    \"\<Esc>" : function("<SID>quit_niffler"),
    \"\<C-G>" : function("<SID>quit_niffler"),
    \"\<C-R>" : function("<SID>paste_from_register")
    \}


" ======================================================================
" Handler Functions
" ======================================================================

function! s:filter_candidate_list(query)
    if empty(b:niffler_candidates)
        return
    endif
    let sanitized_query = s:sanitize_query(a:query)
    let grep_cmd = s:translate_query_to_grep_cmd(sanitized_query)
    let candidates = system(grep_cmd, b:niffler_candidates)
    let candidate_list = split(candidates, "\n")
    if len(candidate_list) < b:niffler_candidate_limit
        let b:niffler_candidates = candidates
    endif
    call s:display(candidate_list)
endfunction


function! s:sanitize_query(query)
    let query = empty(a:query) ? g:niffler_fuzzy_char : a:query
    let fuzzy_char = escape(g:niffler_fuzzy_char, '\')
    let special_chars = substitute('.*[]\', '\V'.fuzzy_char, '', '')
    let sanitized_query = escape(query, special_chars)
    let sanitized_query = substitute(sanitized_query, '\V'.g:niffler_fuzzy_char, '.*', 'g')
    return sanitized_query
endfunction


function! s:translate_query_to_grep_cmd(query)
    let grep_cmd = "grep"
    let grep_cmd_restricted = "grep -m ".b:niffler_candidate_limit
    let search_terms = split(a:query)
    let translator = '"'.grep_cmd.'".((v:val =~# "\\u") ? "" : " -i")." -e \"".v:val."\""'
    let grep_filter_cmd = join(map(search_terms, translator), " | ")
    let grep_filter_cmd_restricted = substitute(grep_filter_cmd, 'grep\ze [^|]*$', grep_cmd_restricted, '')
    return grep_filter_cmd_restricted
endfunction


function! s:display(candidate_list)
    silent! 1,$ delete _
    let candidate_list = a:candidate_list[0:b:niffler_candidate_limit - 1]
    call map(candidate_list, 'substitute(v:val, "$", repeat(" ", winwidth(0)), "")')
    call append(0, candidate_list)
    $ delete _
endfunction


function! s:parse_query(prompt)
    let query = get(split(a:prompt, ":"), 0, "")
    return query
endfunction


function! s:parse_command(prompt)
    let command = get(split(a:prompt, ":"), 1, "")
    return command
endfunction


" ======================================================================
" MRU Handlers
" ======================================================================

function! s:update_mru_list(fname)
    let ignore_buftypes = ['nofile', 'quickfix', 'help', 'terminal']
    let ignore_filetypes = ['gitcommit']
    call extend(ignore_buftypes, g:niffler_mru_ignore_buftypes)
    call extend(ignore_filetypes, g:niffler_mru_ignore_filetypes)

    let ignore_buftype = (index(ignore_buftypes, &l:buftype) != -1)
    let ignore_filetype = (index(ignore_filetypes, &l:filetype) != -1)
    let unlisted = (&l:buflisted == 0)
    let temp = (a:fname =~# '/te\?mp/')
    let vcs_file = (a:fname =~# '/\.\%(git\|svn\|hg\)/')
    let empty_fname = empty(a:fname)
    if !(ignore_buftype || ignore_filetype || unlisted || temp || vcs_file || empty_fname)
        call add(s:mru_list, a:fname)
    endif
endfunction


function! s:prune_mru_list()
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


function! s:write_mru_cache_file()
    call s:prune_mru_list()
    call writefile(s:mru_list, s:mru_cache_file)
endfunction


" ======================================================================
" Commands
" ======================================================================

command! -nargs=* -complete=dir Niffler call <SID>niffler(<q-args>)
command! -nargs=* -complete=dir NifflerGlobal call <SID>niffler_global(<q-args>)
command! -nargs=0 NifflerMRU call <SID>niffler_mru()
command! -nargs=0 NifflerBuffer call <SID>niffler_buffer()
command! -nargs=? NifflerTags call <SID>niffler_tags(<q-args> ==# "%")


" ======================================================================
" Autocommands
" ======================================================================

augroup niffler
    autocmd!
    autocmd BufEnter * call <SID>update_mru_list(expand("%:p"))
    autocmd CursorHold * call <SID>write_mru_cache_file()
augroup END

let &cpoptions = s:save_cpo
unlet s:save_cpo
