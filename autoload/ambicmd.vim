" You can use ambiguous command.
" Version: 0.2.0
" Author : thinca <thinca+vim@gmail.com>
"          Shougo <Shougo.Matsu (at) gmail.com>
"          tyru   <tyru.exe@gmail.com>
" License: Creative Commons Attribution 2.1 Japan License
"          <http://creativecommons.org/licenses/by/2.1/jp/deed.en>
" Install: copy to autoload/ambicmd.vim

let s:save_cpo = &cpo
set cpo&vim

if !exists('g:ambicmd#build_rule')
  let g:ambicmd#build_rule = 'ambicmd#default_rule'
endif

function! ambicmd#default_rule(cmd)
  return [
  \   '\c^' . a:cmd . '$',
  \   a:cmd,
  \   '\C^' . substitute(toupper(a:cmd), '.', '\0\\l*', 'g') . '$',
  \   '\C' . substitute(toupper(a:cmd), '.', '\0\\l*', 'g'),
  \   '.*' . substitute(a:cmd, '.', '\0.*', 'g')
  \ ]
endfunction

" Expand ambiguous command.
" Example:
" autocmd CmdwinEnter * call s:init_cmdwin()
"function! s:init_cmdwin()
  "" Ambicmd.
  "inoremap <buffer><expr> <Space> ambicmd#expand("\<Space>")
  "inoremap <buffer><expr> <CR> ambicmd#expand("\<CR>")

  "startinsert!
"endfunction"}}}
"
" cnoremap <expr> <Space> ambicmd#expand("\<Space>")
" cnoremap <expr> <CR>    ambicmd#expand("\<CR>")
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
  if cmd == '' || state == 1 || state == 2
    return a:key
  endif

  " Get command list.
  redir => cmdlistredir
  silent! command
  redir END
  let cmdlist = map(split(cmdlistredir, "\n")[1 :],
  \                 'matchstr(v:val, ''\a\w*'')')

  let first_matched = []
  " Search matching.
  for pat in call(g:ambicmd#build_rule, [cmd], {})
    let filtered = filter(copy(cmdlist), 'v:val =~? pat')
    if len(filtered) == 1
      let ret = repeat("\<BS>", strlen(cmd)) . filtered[0] . a:key
      if !cmdline
        let ret = (pumvisible() ? "\<C-y>" : '') . ret
      endif
      return ret
    elseif empty(first_matched) && !empty(filtered)
      let first_matched = filtered
    endif
  endfor

  " Expand the head of common part.
  if !empty(first_matched)
    let common = first_matched[0]
    for str in first_matched[1 :]
      let common = matchstr(common, '^\C\%[' . str . ']')
    endfor
    if len(cmd) <= len(common) && cmd !=# common
      return repeat("\<BS>", len(cmd)) . common . "\<C-d>"
    endif
  endif

  return a:key
endfunction

let &cpo = s:save_cpo
