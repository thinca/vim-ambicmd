" You can use ambiguous command.
" Version: 0.3.0
" Authors: thinca <thinca+vim@gmail.com>
"          Shougo <Shougo.Matsu (at) gmail.com>
"          tyru   <tyru.exe@gmail.com>
" License: Creative Commons Attribution 2.1 Japan License
"          <http://creativecommons.org/licenses/by/2.1/jp/deed.en>

let s:save_cpo = &cpo
set cpo&vim

if !exists('g:ambicmd#build_rule')
  let g:ambicmd#build_rule = 'ambicmd#default_rule'
endif

function! ambicmd#default_rule(cmd)
  return [
  \   '\c^' . a:cmd . '$',
  \   '\c^' . a:cmd,
  \   '\c' . a:cmd,
  \   '\C^' . substitute(toupper(a:cmd), '.', '\0\\l*', 'g') . '$',
  \   '\C' . substitute(toupper(a:cmd), '.', '\0\\l*', 'g'),
  \   '.*' . substitute(a:cmd, '.', '\0.*', 'g')
  \ ]
endfunction

" Expand ambiguous command.
function! ambicmd#expand(key)
  let cmdline = mode() ==# 'c'
  if cmdline && getcmdtype() != ':'
    return a:key
  endif
  let line =  cmdline ? getcmdline() : getline('.')
  let pos  = (cmdline ? getcmdpos()  : col('.')) - 1
  if line[pos] =~# '\S'
    return a:key
  endif
  " TODO: The check is incomplete.
  let cmd = matchstr(line[: pos], '^\S\{-}\zs\a\w*')

  let state = exists(':' . cmd)
  if cmd == '' || (cmd =~# '^\l' && state == 1) || state == 2
    return a:key
  endif

  " Get command list.
  redir => cmdlistredir
  silent! command
  redir END
  let cmdlist = map(split(cmdlistredir, "\n")[1 :],
  \                 'matchstr(v:val, ''\a\w*'')')

  let g:ambicmd#last_filtered = []
  " Search matching.
  for pat in call(g:ambicmd#build_rule, [cmd], {})
    let filtered = filter(copy(cmdlist), 'v:val =~? pat')
    call add(g:ambicmd#last_filtered, filtered)
    if len(filtered) == 1
      let ret = repeat("\<BS>", strlen(cmd)) . filtered[0] . a:key
      if !cmdline
        let ret = (pumvisible() ? "\<C-y>" : '') . ret
      endif
      return ret
    endif
  endfor

  " Expand the head of common part.
  for filtered in g:ambicmd#last_filtered
    if empty(filtered)
      continue
    endif
    let common = filtered[0]
    for str in filtered[1 :]
      let common = matchstr(common, '^\C\%[' . str . ']')
    endfor
    if len(cmd) <= len(common) && cmd !=# common
      return repeat("\<BS>", len(cmd)) . common . "\<C-d>"
    endif
  endfor

  return a:key
endfunction

let &cpo = s:save_cpo
