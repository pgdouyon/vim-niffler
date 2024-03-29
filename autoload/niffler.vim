"==============================================================================
"File:        niffler.vim
"Description: Lightweight, fuzzy file finder for Vim.
"Maintainer:  Pierre-Guy Douyon <pgdouyon@alum.mit.edu>
"License:     MIT <../LICENSE>
"==============================================================================

let s:save_cpo = &cpoptions
set cpoptions&vim

" ======================================================================
" Plugin Code
" ======================================================================
function! niffler#niffler(args)
    let dir = matchstr(a:args, '\%(-\S\+\s*\)*\zs.*$')
    let opts = matchstr(a:args, '\%(-\S\+\s*\)\+')
    let vcs = (opts =~# "-vcs")

    let save_wd = getcwd()
    call s:change_working_directory((!empty(dir) ? dir : expand("$HOME")), vcs)

    let candidate_list = s:find_files()
    let niffler_options = {"save_wd": save_wd, "sink": function("s:open_file"),
            \ "display_preprocessor": function("s:sort_by_mru")}
    call s:niffler_setup(candidate_list, niffler_options)
    call s:keypress_event_loop('Files')
endfunction


function! niffler#mru()
    let niffler_options = {"sink": function("s:open_file")}
    call niffler#mru#update()
    call s:niffler_setup(reverse(copy(niffler#mru#list())), niffler_options)
    call s:keypress_event_loop('Mru')
endfunction


function! niffler#buffer()
    try
        if exists("*getbufinfo")
            let bufinfo = getbufinfo({ 'buflisted': v:true })
            let buflist = map(bufinfo, 'fnamemodify(v:val.name, ":.")')
        else
            let ls_output = niffler#utils#redir("ls")
            let buflist = map(split(ls_output, "\n"), 'matchstr(v:val, ''"\zs[^"]\+\ze"'')')
        endif
    catch
        call niffler#utils#echo_error(v:exception)
        return
    endtry

    let niffler_options = {"sink": function("s:open_file"), "display_preprocessor": function("s:sort_by_mru")}
    call s:niffler_setup(buflist, niffler_options)
    call s:keypress_event_loop('Buffers')
endfunction


function! niffler#tags(use_current_buffer)
    if !executable("ctags") || !executable("sed") || !executable("cut")
        let error_message = "[NifflerTags] - one of the following required executables not found: [ctags, sed, cut]."
        call niffler#utils#echo_error(error_message)
        return
    endif
    if a:use_current_buffer
        let [taglist, parse_tag_excmd, parse_tag_filename, display_preprocessor] = s:taglist_current_buffer()
        let conceal_active = 0
        let save_hidden = &hidden
        set hidden
    else
        let [taglist, parse_tag_excmd, parse_tag_filename, display_preprocessor] = s:taglist()
        let conceal_active = g:niffler_conceal_tags_fullpath
    endif
    let niffler_options = {"sink": function("s:open_tag"), "display_preprocessor": display_preprocessor,
            \ "parse_tag_excmd": parse_tag_excmd, "parse_tag_filename": parse_tag_filename}
    call s:niffler_setup(taglist, niffler_options)
    call s:tag_conceal(conceal_active, 1)
    call s:keypress_event_loop('Tags')
    if exists("save_hidden")
        let &hidden = save_hidden
    endif
endfunction


function! s:taglist()
    let taglist = []
    for tagfile in tagfiles()
        let taglist += systemlist(printf("grep -v '^!_TAG_' %s", tagfile))
    endfor

    let parse_tag_excmd = 'printf("/^\\s*\\V%s\\s\\*\\$", escape(matchstr(v:val, ''^\S*\s*.\{-\}\\\@<!\s\+\zs.*''), "/\\"))'
    let parse_tag_filename = 'substitute(matchstr(v:val, ''^\S*\s*\zs.\{-\}\ze\\\@<!\s''), "\\\\ ", " ", "g")'
    let display_preprocessor_fmt_string = 'systemlist("sed %s | cut -f1-3 | column -s ''\t'' -t 2>/dev/null", join(v:val, "\n")."\n")'
    let display_preprocessor = printf(display_preprocessor_fmt_string, s:sed_arguments())
    return [taglist, parse_tag_excmd, parse_tag_filename, display_preprocessor]
endfunction


function! s:taglist_current_buffer()
    let current_buffer = expand("%:p")
    let substitution_pattern = '\V' . escape(current_buffer, '\')
    let taglist = map(systemlist(printf("ctags --fields=kt -f - %s", current_buffer)), 'substitute(v:val, substitution_pattern, "", "g")')

    let parse_tag_excmd = 'printf("/^\\s*\\V%s\\s\\*\\$", escape(matchstr(v:val, ''^\S*\s*\zs.*''), "/\\"))'
    let parse_tag_filename = string(expand("%:p"))
    let display_preprocessor_fmt_string = 'systemlist("sed -e ''%s'' | cut -f1,3 | column -s ''\t'' -t 2>/dev/null", join(v:val, "\n")."\n")'
    let display_preprocessor = printf(display_preprocessor_fmt_string, escape(s:trim_pattern_noise(), '"\'))
    return [taglist, parse_tag_excmd, parse_tag_filename, display_preprocessor]
endfunction


function! s:sed_arguments()
    let not_tab = "[^\t]*"
    let escaped_space = '\1\\ '
    let escape_filename_space = escape(printf("s/^(%s\t%s[^\\\\]) /%s/", not_tab, not_tab, escaped_space), '()')
    let arguments = printf("-e ':loop' -e '%s' -e 't loop' -e '%s'", escape_filename_space, s:trim_pattern_noise())
    return escape(arguments, '"\')
endfunction


function! s:trim_pattern_noise()
    return escape("s:/^[ \t]*(.*)[ \t]*$/;\":\\1:", '^$()')
endfunction


function! niffler#tselect(identifier)
    if !executable("sed") || !executable("cut")
        let error_message = "[NifflerTselect] - one of the following required executables not found: [sed, cut]."
        call niffler#utils#echo_error(error_message)
        return
    endif
    let identifier = empty(a:identifier) ? expand("<cword>") : a:identifier
    try
        let tselect_out = niffler#utils#redir("tselect " . identifier)
    catch
        call niffler#utils#echo_error(v:exception)
        return
    endtry

    let tselect_lines_sanitized = join(split(tselect_out, "\n")[1:-2], "\n")
    let tselect_candidates = []
    for tag in split(tselect_lines_sanitized, '\n\ze\s\{0,2\}\d')
        let file_regex = '\c\V'.identifier.'\s\*\zs\.\*'
        let file = escape(matchstr(split(tag, "\n")[0], file_regex), ' ')
        let tag_location = matchstr(split(tag, "\n")[-1], '^\s*\zs.*')
        let candidate = join([file, tag_location], "\t")
        call add(tselect_candidates, candidate)
    endfor
    execute min([len(tselect_candidates), 10]) "split"
    let parse_tag_excmd = '"/^\\s*\\V" . escape(matchstr(v:val, ''^.\{-\}\\\@<!\s\+\zs.*''), "/\\")'
    let parse_tag_filename = 'substitute(split(v:val, ''\\\@<!\s\+'')[0], "\\\\ ", " ", "g")'
    let display_preprocessor = 'split(system("column -s ''\t'' -t 2>/dev/null", join(v:val, "\n")."\n"), "\n")'
    let niffler_options = {"preview": 1, "sink": function("s:open_tag"), "display_preprocessor": display_preprocessor,
            \ "parse_tag_excmd": parse_tag_excmd, "parse_tag_filename": parse_tag_filename}
    call s:niffler_setup(tselect_candidates, niffler_options)
    call s:tag_conceal(g:niffler_conceal_tags_fullpath, 0)
    call s:keypress_event_loop('Tselect')
endfunction


function! niffler#tjump(identifier)
    let identifier = empty(a:identifier) ? expand("<cword>") : a:identifier
    let matching_tags = taglist("^".identifier."$")
    if len(matching_tags) == 1
        call niffler#tag#push()
        execute "tag" identifier
    else
        call niffler#tselect(identifier)
    endif
endfunction


function! s:open_file(selection) dict
    let save_wd = getcwd()
    call s:lchdir(self.working_directory)
    if buflisted(a:selection)
        execute "silent buffer" bufnr(a:selection)
    else
        execute "silent edit" fnameescape(a:selection)
    endif
    call s:lchdir(save_wd)
endfunction


function! s:open_tag(selection) dict
    let tag_excmd = map([a:selection], self.parse_tag_excmd)[0]
    let tag_filename = map([a:selection], self.parse_tag_filename)[0]
    let open_cmd = buflisted(tag_filename) ? "buffer" : "edit"
    let latest_jump = getpos("''")
    mark '
    call niffler#tag#push()
    try
        execute "silent keepjumps" open_cmd fnameescape(tag_filename)
        execute "silent keeppatterns keepjumps" tag_excmd
        if (&foldopen =~# 'tag') || (&foldopen =~# 'all')
            normal! zv
        endif
    catch
        call niffler#utils#echo_error(substitute(v:exception, '^[^:]*:', '', ''))
        call niffler#tag#pop()
        call setpos("''", latest_jump)
    endtry
endfunction


function! niffler#custom(args)
    if !has_key(a:args, "source")
        let error_message = "[NifflerCustom] - 'source' key not found.  Unable to create candidate list."
        call niffler#utils#echo_error(error_message)
        return
    endif
    let save_wd = getcwd()
    let dir = get(a:args, "dir", "$HOME")
    let vcs = get(a:args, "vcs", 0)
    call s:change_working_directory(dir, vcs)

    if type(a:args.source) == type("")
        let candidates = systemlist(a:args.source)
    elseif type(a:args.source) == type([])
        let candidates = a:args.source
    else
        let candidates = a:args.source()
    endif
    let niffler_options = extend(a:args, {"save_wd": save_wd})
    call s:niffler_setup(candidates, niffler_options)
    call s:keypress_event_loop(get(a:args, "prompt", ""))
endfunction


function! s:change_working_directory(default_dir, vcs_root)
    let dir = a:default_dir
    if a:vcs_root
        let vcs = finddir(".git", expand("%:p:h").";")
        let dir = fnamemodify(vcs, ":h")
    endif
    call s:lchdir(dir)
endfunction


function! s:lchdir(directory)
    let cd = haslocaldir() ? "lchdir!" : "chdir!"
    execute cd a:directory
endfunction


function! s:find_files()
    if !empty(g:niffler_user_command)
        return systemlist(printf(g:niffler_user_command, "."))
    endif
    let find_args = s:get_default_find_args()
    let find_cmd = "find * " . find_args . "2>/dev/null"
    let find_result = systemlist(find_cmd)
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
        let filtered_candidates = systemlist(filter_ignore_files, a:candidates)
        return filtered_candidates
    endif
endfunction


function! s:niffler_setup(candidate_list, options) abort
    if !executable("grep")
        call niffler#utils#echo_error("[Niffler] - `grep` executable not found. Unable to filter candidate list.")
        call s:cleanup_window_state(a:options)
    elseif empty(a:candidate_list)
        call niffler#utils#echo_error("[Niffler] - No results found. Unable to create candidate list.")
        call s:cleanup_window_state(a:options)
    else
        try
            call s:open_niffler_buffer()
            call s:set_niffler_options()
            call s:set_niffler_cursorline()
            call niffler#mru#update()
            call extend(b:niffler, a:options)
            let b:niffler.candidate_list_original = a:candidate_list
            let b:niffler.candidate_list = a:candidate_list
            let b:niffler.candidate_limit = winheight(0)
            let b:niffler.working_directory = getcwd()
            let b:niffler.marked_selections = []
            let b:niffler.isactive = 1
            call s:display(a:candidate_list[0:b:niffler.candidate_limit - 1])
        catch
            call niffler#utils#echo_error(substitute(v:exception, '^[^:]*:', '', ''))
            if exists("b:niffler") && has_key(b:niffler, "origin_buffer")
                call extend(b:niffler, a:options)
                call s:cleanup_buffer_state(b:niffler)
                call niffler#utils#try_visit(b:niffler.origin_buffer, "keepalt")
            endif
            call s:cleanup_window_state(a:options)
        endtry
    endif
endfunction


function! s:open_niffler_buffer() abort
    let save_cursor = getpos(".")
    let origin_buffer = bufnr("%")
    silent keepalt keepjumps edit __Niffler__
    if origin_buffer == bufnr("%")
        " origin buffer was a new/unnamed buffer created with :new or :tabe,
        " create a new one to replace the one Niffler usurped
        keepjumps enew | keepjumps buffer #
        let origin_buffer = bufnr("#")
    endif
    let b:niffler = {}
    let b:niffler.origin_buffer = origin_buffer
    let b:niffler.save_cursor = save_cursor
    keepjumps normal! gg
endfunction


function! s:set_niffler_options()
    let is_hlsearch_suspended = (&hlsearch == 1) && (v:hlsearch == 0)
    let b:niffler.set_hlsearch = &hlsearch ? "set hlsearch" : "set nohlsearch"
    let b:niffler.nohlsearch = is_hlsearch_suspended ? "nohlsearch" : ""
    set nohlsearch
endfunction


function! s:set_niffler_cursorline()
    let save_matches = filter(getmatches(), 'has_key(v:val, "pattern")')
    let b:niffler.save_matches = save_matches | call clearmatches()
    let b:niffler.highlight_group = matchadd("NifflerCursorLine", '^.*\%#.*$', 10)
endfunction


function! s:is_active()
    return exists("b:niffler.isactive")
endfunction


function! s:tag_conceal(conceal_active, use_tag_regex)
    if !a:conceal_active || !s:is_active()
        return
    endif
    let separator = has("win32") ? '\' : '/'
    let sep = escape(separator, '\')
    let tag_regex = (a:use_tag_regex ? '^\S\+\s\+' : '^')
    let isfname_regex = '\%([^'.sep.' ]\|\\\@<= \)*'
    let path_head_regex = tag_regex.'\zs'.sep.'\?\%('.isfname_regex.sep.'\)*'
    execute printf("syntax match NifflerPathHead '%s' conceal", path_head_regex)
endfunction


function! s:keypress_event_loop(prompt_text)
    let prompt = ""
    while s:is_active()
        call s:redraw_prompt(a:prompt_text, prompt)
        silent! let nr = getchar()
        let char = type(nr) == 0 ? nr2char(nr) : nr
        if (char =~# '\p') && (type(nr) == 0)
            let input = char
            while s:character_input_pending()
                let input .= nr2char(getchar(0))
            endwhile
            let prompt = s:update_prompt(prompt, input)
        else
            let mock_fun = "strtrans"
            let prompt = call(get(s:function_map, char, mock_fun), [prompt])
        endif
    endwhile
endfunction


function! s:character_input_pending()
    silent! let nr = getchar(1)
    return nr != 0 && type(nr) == 0 && nr2char(nr) =~# '\p'
endfunction


function! s:update_prompt(prompt, input)
    let prompt = a:prompt . a:input
    let query = s:parse_query(prompt)
    call s:filter_candidate_list(query)
    return prompt
endfunction


function! s:backspace(prompt)
    let prompt = a:prompt[0:-2]
    let query = s:parse_query(prompt)
    let b:niffler.candidate_list = b:niffler.candidate_list_original
    call s:filter_candidate_list(query)
    return prompt
endfunction


function! s:backward_kill_word(prompt)
    let prompt = matchstr(a:prompt, '.\{-\}\ze\S\+\s*$')
    let query = s:parse_query(prompt)
    let b:niffler.candidate_list = b:niffler.candidate_list_original
    call s:filter_candidate_list(query)
    return prompt
endfunction


function! s:backward_kill_line(prompt)
    let empty_prompt = ""
    let b:niffler.candidate_list = b:niffler.candidate_list_original
    call s:filter_candidate_list(empty_prompt)
    return empty_prompt
endfunction


function! s:move_next_line(prompt)
    let is_last_line = (line(".") == line("$"))
    let next_line = (is_last_line ? 1 : line(".") + 1)
    call cursor(next_line, col("."))
    call matchdelete(b:niffler.highlight_group)
    let b:niffler.highlight_group = matchadd("NifflerCursorLine", '^.*\%#.*$', 10)
    return a:prompt
endfunction


function! s:move_prev_line(prompt)
    let is_first_line = (line(".") == 1)
    let prev_line = (is_first_line ? line("$") : line(".") - 1)
    call cursor(prev_line, col("."))
    call matchdelete(b:niffler.highlight_group)
    let b:niffler.highlight_group = matchadd("NifflerCursorLine", '^.*\%#.*$', 10)
    return a:prompt
endfunction


function! s:move_start_line(prompt)
    normal! 0
    return a:prompt
endfunction


function! s:move_end_line(prompt)
    normal! g_
    return a:prompt
endfunction


function! s:redraw_prompt(text, prompt)
    redraw
    echon substitute(g:niffler_prompt, '%s', a:text, '') a:prompt
endfunction


function! s:open_current_window(prompt)
    call s:open_selection(a:prompt, "")
    return ""
endfunction


function! s:open_split_window(prompt)
    call s:open_selection(a:prompt, "split")
    return ""
endfunction


function! s:open_vert_split(prompt)
    call s:open_selection(a:prompt, "vertical split")
    return ""
endfunction


function! s:open_tab_window(prompt)
    call s:open_selection(a:prompt, "tab split")
    return ""
endfunction


function! s:open_selection(prompt, create_window)
    let niffler = b:niffler
    let command = s:parse_command(a:prompt)
    let current_selection = s:cleanup_selection(getline("."))
    call s:close_niffler()

    let original_winnr = winnr()
    let original_tabnr = tabpagenr()
    let alternate_buffer = bufnr("%")
    execute a:create_window
    call niffler#tag#inherit_tag_stack(original_tabnr, original_winnr)
    for selection in niffler.marked_selections
        call s:sink(niffler, selection)
    endfor
    call niffler#utils#try_visit(alternate_buffer, "noautocmd")
    call s:sink(niffler, current_selection)
    execute command
endfunction


function! s:sink(niffler, selection)
    if type(a:niffler.sink) == type("")
        execute a:niffler.sink a:selection
    else
        call a:niffler.sink(a:selection)
    endif
endfunction


function! s:close_niffler(...)
    if !s:is_active()
        return
    endif
    unlet b:niffler.isactive
    let niffler_options = b:niffler
    call s:cleanup_buffer_state(niffler_options)
    call niffler#utils#try_visit(niffler_options.origin_buffer, "keepalt")
    call s:cleanup_window_state(niffler_options)
    redraw | echo
    " above command is needed because Vim leaves the prompt on screen when there are no buffers open
endfunction


function! s:cleanup_buffer_state(saved_state)
    if has_key(a:saved_state, "highlight_group")
        call matchdelete(a:saved_state.highlight_group)
    endif
    if has_key(a:saved_state, "save_matches")
        call setmatches(a:saved_state.save_matches)
    endif
    execute get(a:saved_state, "set_hlsearch", "")
    execute get(a:saved_state, "nohlsearch", "")
endfunction


function! s:cleanup_window_state(saved_state)
    if has_key(a:saved_state, "save_wd")
        call s:lchdir(get(a:saved_state, "save_wd"))
    endif
    if get(a:saved_state, "preview", 0)
        wincmd c
    endif
    if has_key(a:saved_state, "save_cursor")
        call setpos(".", get(a:saved_state, "save_cursor"))
    endif
endfunction


function! s:paste_from_register(prompt)
    let register = getchar()
    let paste_text = s:getreg(register)
    if !empty(paste_text)
        let prompt = a:prompt . paste_text
        let query = s:parse_query(prompt)
        call s:filter_candidate_list(query)
        return prompt
    endif
    return a:prompt
endfunction


function! s:getreg(register)
    if type(a:register) != type(0)
        return ""
    endif

    let register_name = nr2char(a:register)
    if register_name ==# "%"
        return bufname(b:niffler.origin_buffer)
    endif
    return getreg(register_name)
endfunction


function! s:mark_selection(prompt)
    let current_selection = s:cleanup_selection(getline("."))
    let index = index(b:niffler.marked_selections, current_selection)
    if index < 0
        execute printf("normal! I%s", g:niffler_marked_indicator)
        call s:highlight_mark(current_selection)
        call add(b:niffler.marked_selections, current_selection)
    else
        execute printf("normal! 0%dx", strchars(g:niffler_marked_indicator))
        call remove(b:niffler.marked_selections, index)
    endif
    return a:prompt
endfunction


function! s:cleanup_selection(selection)
    let marked_regex = '\V\^' . escape(g:niffler_marked_indicator, '\')
    let trimmed_selection = substitute(a:selection, '\s*$', '', '')
    let is_marked = (trimmed_selection =~# marked_regex)
    if is_marked
        return substitute(trimmed_selection, marked_regex, '', '')
    endif
    return trimmed_selection
endfunction


function! s:highlight_mark(selection)
    let match_pattern = printf('\V\^%s%s \+\$', escape(g:niffler_marked_indicator, '\'), escape(a:selection, '\'))
    call matchadd('NifflerMarkedLine', match_pattern, 0)
endfunction


let s:function_map = {
    \"\<BS>"    : function("<SID>backspace"),
    \"\<C-H>"   : function("<SID>backspace"),
    \"\<C-W>"   : function("<SID>backward_kill_word"),
    \"\<C-U>"   : function("<SID>backward_kill_line"),
    \"\<C-J>"   : function("<SID>move_next_line"),
    \"\<C-N>"   : function("<SID>move_next_line"),
    \"\<Down>"  : function("<SID>move_next_line"),
    \"\<C-K>"   : function("<SID>move_prev_line"),
    \"\<C-P>"   : function("<SID>move_prev_line"),
    \"\<Up>"    : function("<SID>move_prev_line"),
    \"\<C-A>"   : function("<SID>move_start_line"),
    \"\<C-E>"   : function("<SID>move_end_line"),
    \"\<CR>"    : function("<SID>open_current_window"),
    \"\<Right>" : function("<SID>open_current_window"),
    \"\<C-S>"   : function("<SID>open_split_window"),
    \"\<C-V>"   : function("<SID>open_vert_split"),
    \"\<C-T>"   : function("<SID>open_tab_window"),
    \"\<Esc>"   : function("<SID>close_niffler"),
    \"\<C-G>"   : function("<SID>close_niffler"),
    \"\<C-R>"   : function("<SID>paste_from_register"),
    \"\<C-X>"   : function("<SID>mark_selection"),
    \"\<Left>"  : function("<SID>mark_selection"),
    \}


" ======================================================================
" Handler Functions
" ======================================================================

function! s:filter_candidate_list(query)
    if empty(b:niffler.candidate_list)
        return
    endif
    let sanitized_query = s:sanitize_query(a:query)
    let grep_cmd = s:translate_query_to_grep_cmd(sanitized_query)
    silent! let candidate_list = systemlist(grep_cmd, b:niffler.candidate_list)
    if len(candidate_list) < b:niffler.candidate_limit
        let b:niffler.candidate_list = candidate_list
    endif
    call s:display(candidate_list)
    call s:refresh_marks()
endfunction


function! s:sanitize_query(query)
    let query = niffler#utils#empty(a:query) ? g:niffler_fuzzy_char : a:query
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
    let grep_cmd_restricted = printf("grep -m %s", b:niffler.candidate_limit)
    let grep_filter_cmd_restricted = substitute(grep_filter_cmd, last_grep_regex, grep_cmd_restricted, '')
    return grep_filter_cmd_restricted
endfunction


function! s:display(candidate_list)
    keepjumps silent! 1,$ delete _
    let candidate_list = s:preprocess_candidate_list(a:candidate_list)
    call map(candidate_list, 'substitute(v:val, "$", repeat(" ", winwidth(0)), "")')
    call append(0, candidate_list)
    keepjumps $ delete _ | call cursor(1, 1)
endfunction


function! s:preprocess_candidate_list(candidate_list)
    let candidate_list = a:candidate_list
    if exists("b:niffler.display_preprocessor")
        if type(b:niffler.display_preprocessor) == type("")
            let candidate_list = eval(substitute(b:niffler.display_preprocessor, '\<v:val\>', 'a:candidate_list', 'g'))
        else
            let candidate_list = b:niffler.display_preprocessor(a:candidate_list)
        endif
    endif
    return candidate_list
endfunction


function! s:sort_by_mru(candidate_list)
    let candidate_set = s:get_candidate_set(a:candidate_list)
    for file in niffler#mru#list()
        let prefix_directory = escape(getcwd(), '\') . '/'
        let mru_candidate = substitute(file, '\V\^'.prefix_directory, '', '')
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


function! s:refresh_marks()
    let visible_candidate_list = getline(1, "$")
    let refreshed_marked_selections = []
    for lnum in range(1, len(visible_candidate_list))
        let selection = s:cleanup_selection(visible_candidate_list[lnum - 1])
        let is_marked = (index(b:niffler.marked_selections, selection) >= 0)
        if is_marked
            execute printf("%d normal! I%s", lnum, g:niffler_marked_indicator)
            call add(refreshed_marked_selections, selection)
        endif
    endfor
    let b:niffler.marked_selections = refreshed_marked_selections
    call cursor(1, 1)
endfunction


function! s:parse_query(prompt)
    let query = get(split(a:prompt, '\\\@<!:\ze[^:]*$'), 0, "")
    return query
endfunction


function! s:parse_command(prompt)
    let command = get(split(a:prompt, '\\\@<!:\ze[^:]*$'), 1, "")
    return command
endfunction

let &cpoptions = s:save_cpo
unlet s:save_cpo
