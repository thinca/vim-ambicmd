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
  " TODO: The check is incomplete.
  let cmdline = mode() ==# 'c'
  let line = cmdline ? getcmdline() : getline('.')
  let pos  = (cmdline ? getcmdpos()  : col('.')) - 1
  if line[pos] =~# '\S'
    return a:key
  endif
  let cmd = matchstr(line[: pos], '^\S\{-}\zs\a\w*')

  let state = exists(':' . cmd)
  if cmd == '' || state == 1 || state == 2 || state == 3
    return a:key
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
    let filtered = filter(copy(cmdlist), 'v:val =~? pat')
    if len(filtered) == 1
      let ret = repeat("\<BS>", strlen(cmd)) . filtered[0] . a:key
      if !cmdline
        let ret = (pumvisible() ? "\<C-y>" : '') . ret
      endif
      return ret
    endif
  endfor

  return a:key
endfunction

let &cpo = s:save_cpo
unlet s:save_cpo
