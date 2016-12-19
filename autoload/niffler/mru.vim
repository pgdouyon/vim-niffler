let s:save_cpo = &cpoptions
set cpoptions&vim

let s:autoload_folder = expand("<sfile>:p:h:h")
let s:mru_cache_file = s:autoload_folder."/niffler_mru_list.txt"
if !filereadable(s:mru_cache_file)
    call system("touch ".s:mru_cache_file)
endif

" ======================================================================
" Parse MRU Data Structure
" ======================================================================
function! s:parse_mru_file()
    let line_number = -1
    let mru = {'by_filename': {}, 'by_timestamp': {}}
    for line in readfile(s:mru_cache_file)
        let line_number = line_number + 1
        let parsed_ts = matchstr(line, '^\d\+')
        let filename = matchstr(line, '^\%(\d\+ \)\?\zs.*')
        let timestamp = empty(parsed_ts) ? line_number : str2nr(parsed_ts)
        call s:update_mru_entry(mru, filename, timestamp)
    endfor
    return mru
endfunction


" Return a map containing two separate indexes of the MRU list: one by
" filename and one by timestamp.
"
" Crucial that the timestamp index never maps to the same filename more than
" once, otherwise key assumptions about the data structure break.  Said
" another way, there must always be a one-to-one mapping between keys of one
" index and values of the other.
"
" Use the line number when a timestamp isn't available for backwards
" compatibility with old MRU file format
function! s:update_mru_entry(mru, filename, timestamp)
    let existing_timestamp = get(a:mru.by_filename, a:filename, -1)
    if a:timestamp > existing_timestamp
        let a:mru.by_filename[a:filename] = a:timestamp
        let a:mru.by_timestamp[a:timestamp] = a:filename
        if has_key(a:mru.by_timestamp, existing_timestamp)
            call remove(a:mru.by_timestamp, existing_timestamp)
        endif
    endif
endfunction


function! s:most_recent_timestamps(mru)
    let timestamps = sort(keys(a:mru.by_timestamp))
    let mru_size = len(timestamps)
    let start_index = 0
    if mru_size > g:niffler_mru_max_history
        let start_index = mru_size - g:niffler_mru_max_history
    endif
    return timestamps[start_index : -1]
endfunction


function! s:serialize(mru, min_timestamp)
    let entries = []
    for [filename, timestamp] in items(a:mru.by_filename)
        if timestamp >= a:min_timestamp
            call add(entries, timestamp . " " . filename)
        endif
    endfor
    return entries
endfunction


function! s:merge_mru_records(from, to)
    for [filename, timestamp] in items(a:from.by_filename)
        call s:update_mru_entry(a:to, filename, timestamp)
    endfor
    return a:to
endfunction


let s:mru = s:parse_mru_file()
let s:mru_list = []


" ======================================================================
" Public API
" ======================================================================
function! niffler#mru#list()
    return s:mru_list
endfunction


function! niffler#mru#add(fname)
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
        call s:update_mru_entry(s:mru, a:fname, s:timestamp())
    endif
endfunction


function! niffler#mru#update()
    let timestamps = copy(s:most_recent_timestamps(s:mru))
    let filenames = map(timestamps, 'get(s:mru.by_timestamp, v:val, "")')
    let s:mru_list = filter(filenames, '!empty(v:val)')
endfunction


function! niffler#mru#save_file()
    let merged_mru_records = s:merge_mru_records(s:mru, s:parse_mru_file())
    let min_timestamp = s:most_recent_timestamps(merged_mru_records)[0]
    let serialized_entries = s:serialize(merged_mru_records, min_timestamp)
    call writefile(serialized_entries, s:mru_cache_file)
endfunction


function! s:timestamp()
    let [seconds, microseconds] = split(reltimestr(reltime()), '\.')
    return (1000 * seconds) + (microseconds / 1000)
endfunction

let &cpoptions = s:save_cpo
unlet s:save_cpo
