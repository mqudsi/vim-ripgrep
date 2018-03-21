if exists('g:loaded_rg') || &cp
    finish
endif

let g:loaded_rg = 1

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
    let g:rg_root_types = ['.git', 'configure']
endif

let s:last_search = ""

fun! s:Rg(txt)
    call s:RgGrepContext(function('s:RgSearch'), s:RgSearchTerm(a:txt))
endfun

fun! s:RgSearchTerm(txt)
    if empty(a:txt)
        let s:last_search = expand("<cword>")
        return s:last_search
    else
        let s:last_search = a:txt
        let searchtxt = substitute(a:txt, "[%]", "\\\\\\0", "g")
        " let searchtxt = shellescape(searchtxt)
        " :echomsg searchtxt
        return searchtxt
    endif
endfun

fun! s:RgSearch(txt)
    silent! exe 'grep! ' . a:txt
    if len(getqflist())
        copen
        redraw!
        if exists('g:rg_highlight')
            call s:RgHighlight(a:txt)
        endif
    else
        cclose
        redraw!
        " echo "No match found for " . a:txt
        echo "No match found for " . s:last_search
    endif
endfun

fun! s:RgDeriveRoot()
    if exists('g:rg_derive_root')
        return g:rg_derive_root != 0
    else
        return 1
    endif
endfun

fun! s:RgGrepContext(search, txt)
    let l:grepprgb = &grepprg
    let l:grepformatb = &grepformat
    let &grepprg = g:rg_command
    let &grepformat = g:rg_format
    let l:te = &t_te
    let l:ti = &t_ti
    set t_te=
    set t_ti=

    if s:RgDeriveRoot()
        call s:RgPathContext(a:search, a:txt)
    else
        call a:search(a:txt)
    endif

    let &t_te=l:te
    let &t_ti=l:ti
    let &grepprg = l:grepprgb
    let &grepformat = l:grepformatb
endfun

fun! s:RgPathContext(search, txt)
    let l:cwdb = getcwd()
    exe 'lcd '.s:RgRootDir()
    call a:search(a:txt)
    exe 'lcd '.l:cwdb
endfun

fun! s:RgHighlight(txt)
    " let @/=escape(substitute(a:txt, '"', '', 'g'), '|')
    let @/=escape(substitute(s:last_search, '\\', '', 'g'), '|')
    call feedkeys(":let &hlsearch=1\<CR>", 'n')
endfun

fun! s:RgRootDir()
    let l:cwd = getcwd()
    " let l:dirs = split(getcwd(), '/')
    let l:dirs = split(expand('%:p:h'), '/')

    for l:dir in reverse(copy(l:dirs))
        for l:type in g:rg_root_types
            let l:path = s:RgMakePath(l:dirs, l:dir)
            if s:RgHasFile(l:path.'/'.l:type)
                return l:path
            endif
        endfor
    endfor

    return l:cwd
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

command! -nargs=* -complete=file Rg :call s:Rg(<q-args>)
command! -complete=file RgRoot :call s:RgShowRoot()
