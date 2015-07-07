"==============================================================================
"File:        niffler.vim
"Description: Lightweight, fuzzy file finder for Vim.
"Maintainer:  Pierre-Guy Douyon <pgdouyon@alum.mit.edu>
"License:     MIT <../LICENSE>
"==============================================================================

let s:save_cpo = &cpoptions
set cpoptions&vim

" ======================================================================
" Script Local Config
" ======================================================================
let s:prompt = "> "

let s:autoload_folder = expand("<sfile>:p:h")
let s:mru_cache_file = s:autoload_folder."/niffler_mru_list.txt"
if !filereadable(s:mru_cache_file)
    call system("touch ".s:mru_cache_file)
endif
let s:mru_list = readfile(s:mru_cache_file)


" ======================================================================
" Plugin Code
" ======================================================================
function! niffler#niffler(args)
    let dir = matchstr(a:args, '\%(-\S\+\s*\)*\zs.*$')
    let opts = matchstr(a:args, '\%(-\S\+\s*\)\+')
    let vcs = (opts =~# "-vcs")

    let save_wd = getcwd()
    call s:change_working_directory((!empty(dir) ? dir : expand("$HOME")), vcs)

    let candidate_string = s:find_files()
    let niffler_options = {"save_wd": save_wd, "open_cmd": "edit",
            \ "split_cmd": "split", "display_preprocessor": function("s:sort_by_mru")}
    call s:niffler_setup(candidate_string, niffler_options)
    call s:keypress_event_loop()
endfunction


function! niffler#mru()
    let niffler_options = {"open_cmd": "edit", "split_cmd": "split"}
    call s:prune_mru_list()
    call s:niffler_setup(join(reverse(copy(s:mru_list)), "\n"), niffler_options)
    call s:keypress_event_loop()
endfunction


function! niffler#buffer()
    redir => buffers | silent ls | redir END
    let buflist = map(split(buffers, "\n"), 'matchstr(v:val, ''"\zs[^"]\+\ze"'')')
    let buflist_string = join(buflist, "\n")
    let niffler_options = {"open_cmd": "buffer", "split_cmd": "sbuffer",
            \ "display_preprocessor": function("s:sort_by_mru")}
    call s:niffler_setup(buflist_string, niffler_options)
    call s:keypress_event_loop()
endfunction


function! niffler#tags(use_current_buffer)
    if !executable("sed") || !executable("cut")
        throw "[NifflerTags] - `sed` or `cut` executable not found on PATH."
    endif
    if a:use_current_buffer
        let [taglist, parse_tag_excmd, parse_tag_filename, display_preprocessor] = s:taglist_current_buffer()
    else
        let [taglist, parse_tag_excmd, parse_tag_filename, display_preprocessor] = s:taglist()
    endif
    let [open_cmd, split_cmd] = s:get_tag_open_cmds()
    let niffler_options = {"tag_search": 1, "open_cmd": open_cmd, "split_cmd": split_cmd,
            \ "parse_tag_excmd": parse_tag_excmd, "parse_tag_filename": parse_tag_filename,
            \ "display_preprocessor": display_preprocessor}
    call s:niffler_setup(taglist, niffler_options)
    call s:keypress_event_loop()
    call s:delete_tag_open_cmds()
endfunction


function! s:taglist()
    let taglist = ""
    let tagfiles = tagfiles()
    for tagfile in tagfiles
        let not_tab = "[^\t]*"
        let escaped_space = '\1\\ '
        let escape_filename_space = escape(printf("s/^(%s\t%s[^\\]) /%s/", not_tab, not_tab, escaped_space), '()')
        let escape_filename_spaces = printf("-e ':loop' -e '%s' -e 't loop'", escape_filename_space)
        let trim_pattern_noise = escape("-e 's:/^[ \t]*(.*)[ \t]*$/;\":\\1:'", '^$()')
        let tags_cmd = "grep -v ^!_TAG_ %s | sed %s %s | cut -f1-3"
        let tags = system(printf(tags_cmd, tagfile, escape_filename_spaces, trim_pattern_noise))
        let taglist .= tags
    endfor
    let parse_tag_excmd = 'printf("/^\\s*\\V%s", escape(matchstr(v:val, ''^\S*\s*.\{-\}\\\@<!\s\+\zs.*''), "\\"))'
    let parse_tag_filename = 'substitute(matchstr(v:val, ''^\S*\s*\zs.\{-\}\ze\\\@<!\s''), "\\\\ ", " ", "g")'
    let display_preprocessor = 'split(system("column -s ''\t'' -t 2>/dev/null", join(v:val, "\n")."\n"), "\n")'
    return [taglist, parse_tag_excmd, parse_tag_filename, display_preprocessor]
endfunction


function! s:taglist_current_buffer()
    if !executable("ctags")
        throw "[NifflerTags] - `ctags` executable not found."
    else
        let current_buffer = expand("%:p")
        let trim_pattern_noise = escape("s:/^[ \t]*(.*)[ \t]*$/;\":\\1:", '^$()')
        let taglist_cmd = "ctags -f - %s | sed -e '%s' | cut -f1,3"
        let taglist = system(printf(taglist_cmd, current_buffer, trim_pattern_noise))
    endif
    let parse_tag_excmd = 'printf("/^\\s*\\V%s", escape(matchstr(v:val, ''^\S*\s*\zs.*''), "\\"))'
    let parse_tag_filename = string(expand("%:p"))
    let display_preprocessor = 'split(system("column -s ''\t'' -t 2>/dev/null", join(v:val, "\n")."\n"), "\n")'
    return [taglist, parse_tag_excmd, parse_tag_filename, display_preprocessor]
endfunction


function! niffler#tselect(identifier)
    if !executable("sed") || !executable("cut")
        throw "[NifflerTselect] - `sed` or `cut` executable not found on PATH."
    endif
    let identifier = empty(a:identifier) ? expand("<cword>") : a:identifier
    redir => tselect_out
    execute "silent tselect" identifier
    redir END

    let tselect_lines_sanitized = join(split(tselect_out, "\n")[1:-2], "\n")
    let tselect_candidates = []
    for tag in split(tselect_lines_sanitized, '\n\ze\s\{0,2\}\d')
        let file_regex = '\c\V'.identifier.'\s\*\zs\.\*'
        let file = escape(matchstr(split(tag, "\n")[0], file_regex), ' ')
        let tag_location = matchstr(split(tag, "\n")[-1], '^\s*\zs.*')
        let candidate = join([file, tag_location], "\t")
        call add(tselect_candidates, candidate)
    endfor
    execute len(tselect_candidates) "split"
    let parse_tag_excmd = '"/^\\s*\\V" . escape(matchstr(v:val, ''^.\{-\}\\\@<!\s\+\zs.*''), "\\")'
    let parse_tag_filename = 'substitute(split(v:val, ''\\\@<!\s\+'')[0], "\\\\ ", " ", "g")'
    let display_preprocessor = 'split(system("column -s ''\t'' -t 2>/dev/null", join(v:val, "\n")."\n"), "\n")'
    let [open_cmd, split_cmd] = s:get_tag_open_cmds()
    let niffler_options = {"tag_search": 1, "preview": 1, "open_cmd": open_cmd, "split_cmd": split_cmd,
            \ "parse_tag_excmd": parse_tag_excmd, "parse_tag_filename": parse_tag_filename,
            \ "display_preprocessor": display_preprocessor}
    call s:niffler_setup(join(tselect_candidates, "\n"), niffler_options)
    call s:keypress_event_loop()
    call s:delete_tag_open_cmds()
endfunction


function! niffler#tjump(identifier)
    let identifier = empty(a:identifier) ? expand("<cword>") : a:identifier
    let matching_tags = taglist("^".identifier."$")
    if len(matching_tags) == 1
        execute "tag" identifier
    else
        call niffler#tselect(identifier)
    endif
endfunction


function! s:get_tag_open_cmds()
    command! -nargs=+ -bar NifflerTagOpenCmd try | buffer <args> | catch | edit <args> | endtry
    return ["NifflerTagOpenCmd", "split | NifflerTagOpenCmd"]
endfunction


function! s:delete_tag_open_cmds()
    silent! delcommand NifflerTagOpenCmd
endfunction


function! s:change_working_directory(default_dir, vcs_root)
    let dir = a:default_dir
    if a:vcs_root
        let vcs = finddir(".git", expand("%:p:h").";")
        let dir = fnamemodify(vcs, ":h")
    endif
    execute "lchdir! ".dir
endfunction


function! s:find_files()
    if !empty(g:niffler_user_command)
        return system(printf(g:niffler_user_command, "."))
    endif
    let find_args = s:get_default_find_args()
    let find_cmd = "find * " . find_args . "2>/dev/null"
    let find_result = system(find_cmd)
    return s:filter_ignore_files(find_result)
endfunction


function! s:get_default_find_args()
    let ignore_path_args = ""
    if !empty(g:niffler_ignore_dirs)
        let generate_path_expr = 'printf("-path %s", shellescape("*".substitute(v:val, "[^/]$", "\\0/", ""). "*"))'
        let ignore_dirs = join(map(copy(g:niffler_ignore_dirs), generate_path_expr), " -o ")
        let ignore_path_args = '\( '.ignore_dirs.' \) -prune -o '
    endif
    return ignore_path_args . ' -path "*/\.*" -prune -o \( -type f -o -type l \) -print '
endfunction


function! s:filter_ignore_files(candidates)
    if empty(g:niffler_ignore_extensions)
        return a:candidates
    else
        let escape_period = 'escape(v:val, ".")'
        let ignore_files = join(map(copy(g:niffler_ignore_extensions), escape_period), '\|')
        let filter_ignore_files = 'grep -v -e ' . shellescape('\('.ignore_files.'\)$')
        let filtered_candidates = system(filter_ignore_files, a:candidates)
        return filtered_candidates
    endif
endfunction


function! s:niffler_setup(candidate_string, options)
    if !executable("grep")
        throw "[Niffler] - `grep` executable not found. Unable to filter candidate list."
    endif
    call s:open_niffler_buffer()
    call s:set_niffler_options()
    call s:set_niffler_cursorline()
    call s:prune_mru_list()
    let b:niffler_candidates_original = a:candidate_string
    let b:niffler_candidates = a:candidate_string
    let b:niffler_candidate_limit = winheight(0)
    let b:niffler_isactive = 1
    for option_pair in items(a:options)
        let b:niffler_{option_pair[0]} = option_pair[1]
    endfor
    call s:display(split(a:candidate_string, "\n")[0:b:niffler_candidate_limit - 1])
endfunction


function! s:open_niffler_buffer()
    let origin_buffer = bufname("%")
    let save_cursor = getpos(".")
    keepalt keepjumps edit __Niffler__
    let b:niffler_origin_buffer = origin_buffer
    let b:niffler_save_cursor = save_cursor
endfunction


function! s:set_niffler_options()
    let enabled_boolean_options = filter(["fen", "wrap", "spell", "cuc", "nu", "rnu", "hls"], 'eval("&".v:val)')
    let restore_options = "setlocal foldcolumn=%d colorcolumn=%s %s"
    let b:niffler_restore_options = printf(restore_options, &foldcolumn, &colorcolumn, join(enabled_boolean_options))
    set filetype=niffler
    setlocal buftype=nofile
    setlocal bufhidden=wipe
    silent! setlocal foldcolumn=0
    silent! setlocal colorcolumn=""
    silent! setlocal buflisted noswapfile nospell nofoldenable noreadonly nowrap
    silent! setlocal nocursorcolumn nonumber norelativenumber nohlsearch
endfunction


function! s:set_niffler_cursorline()
    let save_matches = filter(getmatches(), 'has_key(v:val, "pattern")')
    let b:niffler_save_matches = save_matches | call clearmatches()
    let b:niffler_highlight_group = matchadd("NifflerCursorLine", '^.*\%#.*$', 0)
endfunction


function! s:keypress_event_loop()
    normal! gg
    let prompt = ""
    call s:redraw_prompt(prompt)
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
    call s:redraw_prompt(prompt)
    return prompt
endfunction


function! s:backspace(prompt)
    let prompt = a:prompt[0:-2]
    let query = s:parse_query(prompt)
    let b:niffler_candidates = b:niffler_candidates_original
    call s:filter_candidate_list(query)
    call s:redraw_prompt(prompt)
    return prompt
endfunction


function! s:backward_kill_word(prompt)
    let prompt = matchstr(a:prompt, '.\{-\}\ze\S\+\s*$')
    let query = s:parse_query(prompt)
    let b:niffler_candidates = b:niffler_candidates_original
    call s:filter_candidate_list(query)
    call s:redraw_prompt(prompt)
    return prompt
endfunction


function! s:backward_kill_line(prompt)
    let empty_prompt = ""
    let b:niffler_candidates = b:niffler_candidates_original
    call s:filter_candidate_list(empty_prompt)
    call s:redraw_prompt(empty_prompt)
    return empty_prompt
endfunction


function! s:move_next_line(prompt)
    let is_last_line = (line(".") == line("$"))
    let next_line = (is_last_line ? 1 : line(".") + 1)
    call cursor(next_line, col("."))
    call matchdelete(b:niffler_highlight_group)
    let b:niffler_highlight_group = matchadd("NifflerCursorLine", '^.*\%#.*$', 0)
    call s:redraw_prompt(a:prompt)
    return a:prompt
endfunction


function! s:move_prev_line(prompt)
    let is_first_line = (line(".") == 1)
    let prev_line = (is_first_line ? line("$") : line(".") - 1)
    call cursor(prev_line, col("."))
    call matchdelete(b:niffler_highlight_group)
    let b:niffler_highlight_group = matchadd("NifflerCursorLine", '^.*\%#.*$', 0)
    call s:redraw_prompt(a:prompt)
    return a:prompt
endfunction


function! s:scroll_left(prompt)
    normal! zH
    call s:redraw_prompt(a:prompt)
    return a:prompt
endfunction


function! s:scroll_right(prompt)
    normal! zL
    call s:redraw_prompt(a:prompt)
    return a:prompt
endfunction


function! s:redraw_prompt(prompt)
    redraw
    echon s:prompt a:prompt
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
    if get(b:, "niffler_tag_search", 0)
        call s:open_tag(a:prompt, a:open_cmd)
    else
        call s:open_file(a:prompt, a:open_cmd)
    endif
endfunction


function! s:open_file(prompt, open_cmd)
    let prompt = s:parse_query(a:prompt)
    let command = s:parse_command(a:prompt)
    let selection = fnamemodify(substitute(getline("."), '\s*$', '', ''), ":p")
    call s:close_niffler()
    execute a:open_cmd fnameescape(selection)
    execute command
endfunction


function! s:open_tag(prompt, open_cmd)
    let selection = substitute(getline("."), '\s*$', '', '')
    let tag_excmd = map([selection], b:niffler_parse_tag_excmd)[0]
    let tag_filename = map([selection], b:niffler_parse_tag_filename)[0]
    call s:close_niffler()
    normal! m'
    execute "silent" a:open_cmd fnameescape(tag_filename) "|silent keeppatterns" tag_excmd
endfunction


function! s:close_niffler(...)
    unlet b:niffler_isactive
    let save_wd = get(b:, "niffler_save_wd", getcwd())
    let preview = get(b:, "niffler_preview", 0)
    let save_cursor = b:niffler_save_cursor
    let niffler_buffer = bufnr("%")
    call matchdelete(b:niffler_highlight_group)
    call setmatches(b:niffler_save_matches)
    execute b:niffler_restore_options
    execute "keepalt keepjumps buffer" b:niffler_origin_buffer
    execute "silent! bwipeout!" niffler_buffer
    execute "lchdir!" save_wd
    if preview | wincmd c | endif
    call setpos(".", save_cursor)
    redraw | echo
    " above command is needed because Vim leaves the prompt on screen when there are no buffers open
endfunction


function! s:paste_from_register(prompt)
    let register = getchar()
    if !type(register)
        let paste_text = getreg(nr2char(register))
        let prompt = a:prompt . paste_text
        let query = s:parse_query(prompt)
        call s:filter_candidate_list(query)
        call s:redraw_prompt(prompt)
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
    \"\<C-A>" : function("<SID>scroll_left"),
    \"\<C-E>" : function("<SID>scroll_right"),
    \"\<CR>"  : function("<SID>open_current_window"),
    \"\<C-S>" : function("<SID>open_split_window"),
    \"\<C-V>" : function("<SID>open_vert_split"),
    \"\<C-T>" : function("<SID>open_tab_window"),
    \"\<Esc>" : function("<SID>close_niffler"),
    \"\<C-G>" : function("<SID>close_niffler"),
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
    let sanitized_query = substitute(sanitized_query, '\V'.fuzzy_char, '.*', 'g')
    return sanitized_query
endfunction


function! s:translate_query_to_grep_cmd(query)
    let search_terms = split(a:query)
    let translator = 'printf("grep %s -e %s", (v:val =~# "\\u") ? "" : "-i", shellescape(v:val))'
    let grep_filter_cmd = join(map(search_terms, translator), " | ")
    let last_grep_regex = 'grep\ze [^|]*$'
    let grep_cmd_restricted = printf("grep -m %s", b:niffler_candidate_limit)
    let grep_filter_cmd_restricted = substitute(grep_filter_cmd, last_grep_regex, grep_cmd_restricted, '')
    return grep_filter_cmd_restricted
endfunction


function! s:display(candidate_list)
    silent! 1,$ delete _
    let candidate_list = s:preprocess_candidate_list(a:candidate_list)
    call map(candidate_list, 'substitute(v:val, "$", repeat(" ", winwidth(0)), "")')
    call append(0, candidate_list)
    $ delete _ | call cursor(1, 1)
endfunction


function! s:preprocess_candidate_list(candidate_list)
    let candidate_list = a:candidate_list
    if exists("b:niffler_display_preprocessor")
        if type(b:niffler_display_preprocessor) == type("")
            let candidate_list = eval(substitute(b:niffler_display_preprocessor, '\<v:val\>', 'a:candidate_list', 'g'))
        else
            let candidate_list = b:niffler_display_preprocessor(a:candidate_list)
        endif
    endif
    return candidate_list
endfunction


function! s:sort_by_mru(candidate_list)
    let candidate_set = s:get_candidate_set(a:candidate_list)
    for mru in s:mru_list
        let prefix_directory = escape(getcwd(), '\') . '/'
        let mru_candidate = substitute(mru, '\V\^'.prefix_directory, '', '')
        if has_key(candidate_set, mru_candidate)
            let index = index(a:candidate_list, mru_candidate)
            call insert(a:candidate_list, remove(a:candidate_list, index))
        endif
    endfor
    return a:candidate_list
endfunction


function! s:get_candidate_set(candidate_list)
    let candidate_set = {}
    for candidate in a:candidate_list
        let candidate_set[candidate] = 0
    endfor
    return candidate_set
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

function! niffler#update_mru_list(fname)
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


function! niffler#write_mru_cache_file()
    call s:prune_mru_list()
    call writefile(s:mru_list, s:mru_cache_file)
endfunction


let &cpoptions = s:save_cpo
unlet s:save_cpo
