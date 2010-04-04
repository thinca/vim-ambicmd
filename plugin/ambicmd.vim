" You can use ambiguous command.
" Version: 0.1.0
" Author : thinca <thinca+vim@gmail.com>
" License: Creative Commons Attribution 2.1 Japan License
"          <http://creativecommons.org/licenses/by/2.1/jp/deed.en>

if exists('g:loaded_ambicmd') || v:version < 702
  finish
endif
let g:loaded_ambicmd = 1

let s:save_cpo = &cpo
set cpo&vim

" Ambiguous command.
function! s:ambicmd(key)
  if getcmdtype() != ':'
    return a:key
  endif

  " TODO: The check is incomplete.
  let cmd = matchstr(getcmdline()[:getcmdpos()], '^\S\{-}\zs\a\w*')

  let state = exists(':' . cmd)
  if cmd == '' || state == 1 || state == 2
    return a:key
  endif
  if state == 3
    return "\<C-d>"
  endif

  " Get command list.
  redir => cmdlistredir
  silent! command
  redir END
  let cmdlist = map(split(cmdlistredir, "\n")[1:],
        \ 'matchstr(v:val, ''\a\w*'')')

  " Search matching.
  for pat in [
  \ '\c^' . cmd . '$',
  \ cmd,
  \ '\C^' . substitute(toupper(cmd), '.', '\0\\l*', 'g') . '$',
  \ '\C' . substitute(toupper(cmd), '.', '\0\\l*', 'g'),
  \ '.*' . substitute(cmd, '.', '\0.*', 'g')]
    let filtered = filter(copy(cmdlist), 'v:val =~? ' . string(pat))
    if len(filtered) == 1
      return repeat("\<BS>", strlen(cmd)) . filtered[0] . a:key
    endif
  endfor

  return a:key
endfunction

" TODO: Uncustomizable.
cnoremap <expr> <Space> <SID>ambicmd("\<Space>")


let &cpo = s:save_cpo
unlet s:save_cpo
