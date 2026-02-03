if exists('g:loaded_rg') || &cp
    finish
endif

let g:loaded_rg = 1

" --- Configuration ---
if !exists('g:rg_binary')
    let g:rg_binary = 'rg'
endif

if !exists('g:rg_format')
    let g:rg_format = "%f:%l:%c:%m"
endif

if !exists('g:rg_command')
    let g:rg_command = g:rg_binary . ' --vimgrep'
endif

if !exists('g:rg_root_types')
    let g:rg_root_types = [
        \ '.git',
        \ 'Cargo.toml',
        \ 'CMakeLists.txt',
        \ 'Makefile',
        \ 'go.mod',
        \ 'package.json',
        \ 'pyproject.toml',
        \ 'tsconfig.json',
        \ '.ignore'
    \ ]
endif

let s:last_search = ""

" --- Core Functions ---
fun! s:Rg(txt)
    call s:RgGrepContext(function('s:RgSearch'), s:RgSearchTerm(a:txt))
endfun

fun! s:RgSearchTerm(txt)
    if empty(a:txt)
        let s:last_search = expand("<cword>")
        return s:last_search
    else
        let s:last_search = a:txt
        " Escape % for Vim command line, though grep! usually handles it
        let searchtxt = substitute(a:txt, "[%]", "\\\\\\0", "g")
        return searchtxt
    endif
endfun

fun! s:RgSearch(txt)
    " Execute the grep
    silent! exe 'grep! ' . a:txt

    if len(getqflist())
        copen
        redraw
        if exists('g:rg_highlight')
            call s:RgHighlight(a:txt)
        endif
    else
        cclose
        redraw
        echo "No match found for " . s:last_search
    endif
endfun

fun! s:RgDeriveRoot()
    return get(g:, 'rg_derive_root', 1)
endfun

fun! s:RgGrepContext(search, txt)
    " Save global grep settings
    let l:grepprgb = &grepprg
    let l:grepformatb = &grepformat
    let &grepprg = g:rg_command
    let &grepformat = g:rg_format

    " Prevent screen flickering during silent grep
    let l:te = &t_te
    let l:ti = &t_ti
    set t_te=
    set t_ti=

    if s:RgDeriveRoot()
        call s:RgPathContext(a:search, a:txt)
    else
        call a:search(a:txt)
    endif

    " Restore settings
    let &t_te = l:te
    let &t_ti = l:ti
    let &grepprg = l:grepprgb
    let &grepformat = l:grepformatb
endfun

fun! s:RgPathContext(search, txt)
    let l:orig_win = win_getid()
    let l:orig_cwd = getcwd()
    let l:root = s:RgRootDir()

    " Change directory in the current window.
    exe 'lcd ' . fnameescape(l:root)

    try
        call a:search(a:txt)
    finally
        " Restore directory specifically in the window we started from.
        " This prevents the Quickfix window focus from breaking the CWD restore.
        if exists('*win_execute')
            call win_execute(l:orig_win, 'lcd ' . fnameescape(l:orig_cwd))
        else
            " Fallback for older Vim versions
            let l:curr_win = win_getid()
            call win_gotoid(l:orig_win)
            exe 'lcd ' . fnameescape(l:orig_cwd)
            call win_gotoid(l:curr_win)
        endif
    endtry
endfun

" --- Helper Functions ---
fun! s:RgHighlight(txt)
    let @/ = escape(substitute(s:last_search, '\\', '', 'g'), '|')
    call feedkeys(":let &hlsearch=1\<CR>", 'n')
endfun

fun! s:RgRootDir()
    let l:start_dir = expand('%:p:h')

    " If buffer has no file, or we are in a special buffer, use CWD
    if empty(l:start_dir) || &buftype != ''
        return getcwd()
    endif

    let l:curr = l:start_dir
    let l:home = $HOME

    " Search ancestors for project root
    while 1
        for l:type in g:rg_root_types
            let l:path = l:curr . '/' . l:type
            if filereadable(l:path) || isdirectory(l:path)
                return l:curr
            endif
        endfor

        " Abort search at pre-defined stopping points
        if l:curr ==# l:home || l:curr ==# '/' || l:curr ==# fnamemodify(l:curr, ':h')
            break
        endif

        let l:curr = fnamemodify(l:curr, ':h')
    endwhile

    " Default to CWD if no project root was found
    return getcwd()
endfun

fun! s:RgMakePath(dirs, dir)
    return '/'.join(a:dirs[0:index(a:dirs, a:dir)], '/')
endfun

fun! s:RgHasFile(path)
    return filereadable(a:path) || isdirectory(a:path)
endfun

fun! s:RgShowRoot()
    if s:RgDeriveRoot()
        echo s:RgRootDir()
    else
        echo getcwd()
    endif
endfun

" --- Commands ---
command! -nargs=* -complete=file Rg :call s:Rg(<q-args>)
command! -nargs=* -complete=file RgRoot :call s:RgShowRoot()
