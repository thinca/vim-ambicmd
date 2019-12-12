if !exists('g:ambicmd#build_rule')
  let g:ambicmd#build_rule = 'ambicmd#default_rule'
endif
if !exists('g:ambicmd#show_completion_menu')
  let g:ambicmd#show_completion_menu = 0
endif

function! ambicmd#default_rule(cmd) abort
  return [
  \   '\c^' . a:cmd . '$',
  \   '\c^' . a:cmd,
  \   '\c' . a:cmd,
  \   '\C^' . substitute(toupper(a:cmd), '.', '\0\\l*', 'g') . '$',
  \   '\C' . substitute(toupper(a:cmd), '.', '\0\\l*', 'g'),
  \   '.*' . substitute(a:cmd, '.', '\0.*', 'g')
  \ ]
endfunction

function! s:escape_for_very_magic(str) abort
  return escape(a:str, '\.^$?*+~()[]{@|=&')
endfunction

function! s:PATTERN_NON_ESCAPE_CHAR(char, ...) abort
  let force_escape = exists('a:1') ? a:1 : 1
  return '\v%(%(\_^|[^\\])%(\\\\)*)@<=' .
  \   (force_escape ? s:escape_for_very_magic(a:char) : a:char)
endfunction

function! s:generate_range_matcher() abort
  let range_factor_search = printf('%%(/.*%s|\?.*%s)',
  \   s:PATTERN_NON_ESCAPE_CHAR('/'),
  \   s:PATTERN_NON_ESCAPE_CHAR('?'))
  let range_factors = [
  \   '\d+',
  \   '[.$%]',
  \   "'.",
  \   range_factor_search . '%(' . range_factor_search . ')?',
  \   '\\[/?&]',
  \ ]
  let range_specifier = '%(' . join(range_factors, '|') .
  \   ')%(\s*[+-]\d+)?'
  return '\v' . range_specifier . '%(\s*[,;]\s*' .
  \   range_specifier . ')?'
endfunction

let s:PATTERN_RANGE = s:generate_range_matcher()
let s:PATTERN_NON_ESCAPE_WHITESPACE = s:PATTERN_NON_ESCAPE_CHAR('\s', 0)
let s:PATTERN_NON_ESCAPE_BAR = s:PATTERN_NON_ESCAPE_CHAR('|')
let s:PATTERN_SINGLE_QUOTE_PAIR = ["'", '\v%(%(\_^|[^''])%('''')*)@<=''%([^'']|$)@=']
let s:PATTERN_DOUBLE_QUOTE_PAIR = ['"', s:PATTERN_NON_ESCAPE_CHAR('"')]

" NOTE: Keys are evaluated under very magic.
let s:TABLE_SPECIAL_CMDS = {
\   'g%[lobal]': 'global',
\   'v%[global]': 'global',
\   'exe%[cute]': 'execute',
\   }


function! s:has_item(list, item) abort
  return index(a:list, a:item) != -1
endfunction

function! s:str_divide_pos(string, pos) abort
  " NOTE: Use strpart() by considering a:pos == 0.
  return [strpart(a:string, 0, a:pos), a:string[a:pos :]]
endfunction

function! s:get_cmd_list() abort
  redir => cmdlistredir
  silent! command
  redir END
  return map(split(cmdlistredir, "\n")[1 :],
  \   'matchstr(v:val, ''\u\w*'')')
endfunction

function! s:get_cmdline_info() abort
  let is_cmdline = s:has_item(['c', 'v', 'V', "\<C-v>"], mode())
  if !is_cmdline
    if exists('*getcmdwintype')
      let cmdtype = getcmdwintype()
      let is_cmdwin = (cmdtype !=# '')
    else
      if (bufname('%') ==# '[Command Line]') && (&l:filetype ==# 'vim') &&
      \  (!&l:rightleft) && (&l:buftype ==# 'nofile') && (!&l:swapfile)
        let is_cmdwin = 1
        let cmdtype = ':'
      else
        let is_cmdwin = 0
        let cmdtype = ''
      endif
    endif
  else
    let is_cmdwin = 0
    let cmdtype = getcmdtype()
  endif
  return [is_cmdline, is_cmdwin, cmdtype]
endfunction

function! s:remove_range_specifier(cmdline) abort
  return substitute(a:cmdline, '\v^\s*\zs' . s:PATTERN_RANGE, '', '')
endfunction

function! s:remove_head_whitespace(cmdline) abort
  return substitute(a:cmdline, '^\s*', '', '')
endfunction

function! s:cancel_expanding() abort
  throw 'ambicmd: CancelExpanding'
endfunction

function! s:get_identifier_if_special_cmd(cmdbase) abort
  let cmdbase = matchstr(a:cmdbase, '^\s*\zs\w*') " Get command name
  if cmdbase ==# ''
    return ''
  endif
  for [key, identifier] in items(s:TABLE_SPECIAL_CMDS)
    if cmdbase =~# '\v^' . key . '$'
      return identifier
    endif
  endfor
  return ''
endfunction

function! s:separate_cmd_bang(cmd) abort
  if a:cmd[-1 :] ==# '!'
    let bang = '!'
    let target = a:cmd[: -2]
  else
    let bang = ''
    let target = a:cmd
  endif
  return [target, bang]
endfunction

function! s:parse_cmd(cmdline) abort
  let cmdline = a:cmdline
  while 1
    let cmdline = s:remove_range_specifier(cmdline)
    if cmdline =~# '^\s*$'
      call s:cancel_expanding()
    endif
    let identifier = s:get_identifier_if_special_cmd(cmdline)
    if identifier !=# ''
      return s:parse_cmd_{identifier}(s:remove_head_whitespace(cmdline))
    endif

    let index = match(cmdline, s:PATTERN_NON_ESCAPE_BAR)
    if index == -1
      break
    endif
    let cmdline = cmdline[index + 1 :]
  endwhile

  if cmdline =~# '^\s'
    call s:cancel_expanding()
  endif

  let [target, bang] = s:separate_cmd_bang(cmdline)
  if match(target, '\A') == -1
    return [target, bang]
  else
    call s:cancel_expanding()
  endif
endfunction

function! s:parse_cmd_global(cmdline) abort
  let cmdargs = matchstr(a:cmdline,
  \   '\v^%(g%[lobal]!?|v%[global])\s*\zs.*')
  if cmdargs ==# ''
    call s:cancel_expanding()
  endif
  let pattern_separator = s:PATTERN_NON_ESCAPE_CHAR(cmdargs[0])
  let arg_command = matchstr(cmdargs,
  \   '\v^' . pattern_separator . '.{-}' . pattern_separator . '\zs.*$')
  if arg_command ==# ''
    call s:cancel_expanding()
  else
    return s:parse_cmd(arg_command)
  endif
endfunction

function! s:parse_cmd_execute(cmdline) abort
  let cmdline = matchstr(a:cmdline,
  \   '\v^exe%[cute]\s+\zs.*')
  if cmdline ==# ''
    call s:cancel_expanding()
  endif
  while 1
    let pos = {}
    let pos.single_quote = match(cmdline, "'")
    let pos.double_quote = match(cmdline, '"')
    let pos.bar = match(cmdline, s:PATTERN_NON_ESCAPE_BAR)

    let closest = {'kind': '', 'pos': -1}
    for [kind, match_pos] in items(pos)
      if match_pos == -1
        continue
      elseif (closest.pos == -1) || (match_pos < closest.pos)
        let closest.kind = kind
        let closest.pos = match_pos
      endif
    endfor
    if closest.pos == -1
      call s:cancel_expanding()
    endif
    if closest.kind ==# 'bar'
      let cmdline = cmdline[closest.pos + 1 :]
      break
    endif
    let closest.kind = toupper(closest.kind)
    let pos_pair = match(cmdline,
    \   s:PATTERN_{closest.kind}_PAIR[1], closest.pos + 1)
    if pos_pair == -1
      let cmdline = cmdline[closest.pos :]

      " Unescape single/double quotes.
      let cmdline = eval(cmdline . s:PATTERN_{closest.kind}_PAIR[0])
      break
    else
      let cmdline = cmdline[pos_pair + 1 :]
    endif
  endwhile

  return s:parse_cmd(cmdline)
endfunction

function! s:get_completion(target) abort
  if a:target ==# ''
    call s:cancel_expanding()
  endif
  let cmdstate = exists(':' . a:target)
  if (cmdstate == 2) || (a:target =~# '^\l' && cmdstate == 1)
    call s:cancel_expanding()
  endif

  let commands = s:get_cmd_list()
  let filtered_list = []

  " Try to find the only completion.
  for pattern in call(g:ambicmd#build_rule, [a:target])
    let filtered = filter(copy(commands), 'v:val =~? pattern')
    if len(filtered) == 1
      return [filtered[0], 1]
    endif
    call add(filtered_list, filtered)
  endfor

  " Emulate "longest" function of 'wildmode'.
  for filtered in filtered_list
    if empty(filtered)
      continue
    endif
    let common = filtered[0]
    for completion in filtered[1 :]
      let common = matchstr(common, '^\C\%[' . completion . ']')
    endfor
    if strlen(common) >= strlen(a:target)
      return [common, 0]
    endif
  endfor

  call s:cancel_expanding()
endfunction

function! ambicmd#expand(keys) abort
  let [is_cmdline, is_cmdwin, cmdtype] = s:get_cmdline_info()
  if (is_cmdline || is_cmdwin) && cmdtype !=# ':'
    return a:keys
  endif
  let [cmdline, after_cursor] = s:str_divide_pos(
  \   (is_cmdline ? getcmdline() : getline('.')),
  \   (is_cmdline ? getcmdpos() : col('.')) - 1
  \   )
  if after_cursor =~# '^\w' || cmdline ==# ''
    return a:keys
  endif

  try
    let [target, bang] = s:parse_cmd(cmdline)
    let [completion, is_fullmatch] = s:get_completion(target)
  catch /^ambicmd\:\sCancelExpanding$/
    return a:keys
  endtry
  if target ==# completion && is_fullmatch
    return a:keys
  endif

  let prefix = (!is_cmdline && pumvisible()) ? "\<C-y>" : ''

  if is_fullmatch
    let suffix = a:keys
  elseif is_cmdline
    if g:ambicmd#show_completion_menu && &wildmenu && &wildcharm != 0
      let suffix = nr2char(&wildcharm)
    else
      let suffix = "\<C-d>"
    endif
  elseif is_cmdwin && g:ambicmd#show_completion_menu
    let suffix = "\<C-x>\<C-v>"
  else
    let suffix = ''
  endif

  if is_fullmatch
    let completion .= bang
  endif
  return prefix . repeat("\<C-h>", strlen(target . bang)) . completion . suffix
endfunction
