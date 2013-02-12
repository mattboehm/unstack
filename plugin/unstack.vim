"TODO add 'quit' function/shortcut that removes marks

if exists('g:loaded_unstack')
  finish
endif
let g:loaded_unstack = 1
let s:unstack_signs = {}

augroup unstack_signClear
  autocmd!
  autocmd TabEnter * call s:RemoveSignsFromClosedTabs()
augroup end

"Settings {{{
if !exists('g:unstack_mapkey')
  let g:unstack_mapkey = '<leader>s'
endif
exe 'nnoremap '.g:unstack_mapkey.' :set operatorfunc=<SID>StackTrace<cr>g@'
exe 'vnoremap '.g:unstack_mapkey.' :<c-u>call <SID>StackTrace(visualmode())<cr>'

"Regular expressions for a line of stacktrace. The file path and line number
"should be surrounded by parentheses so that they are captured as groups
if (!exists('g:unstack_patterns'))
  let g:unstack_patterns = [['\v^ *File "([^"]+)", line ([0-9]+).+', '\1', '\2']]
endif

"Whether or not to show signs on error lines (highlights them red)
if !exists('g:unstack_showsigns')
  let g:unstack_showsigns = 1
endif "}}}

"StackTrace(type) called by hotkeys {{{
function! s:StackTrace(type)
  let sel_save = &selection
  let &selection = "inclusive"
  let reg_save = @@

  if a:type ==# 'V'
    execute "normal! `<V`>y"
  elseif a:type ==# 'v'
    execute "normal! `<v`>y"
  elseif a:type ==# 'char'
    execute "normal! `[v`]y"
  elseif a:type ==# 'line'
    execute "normal! `[V`]y"
  else
    let &selection = sel_save
    let @@ = reg_save
    return
  endif

  let files = s:ExtractFiles(@@)
  call s:OpenStackTrace(files)

  let &selection = sel_save
  let @@ = reg_save
endfunction "}}}

"ExtractFiles(stacktrace) extract files and lines from a stacktrace {{{
"return [[file1, line1], [file2, line2] ... ] from a stacktrace 
function! s:ExtractFiles(stacktrace)
  for [regex, file_replacement, line_replacement] in g:unstack_patterns
    let files = []
    for line in split(a:stacktrace, "\n")
      let fname = substitute(line, regex, file_replacement, '')
      "if this line has a matching filename
      if (fname != line)
        let lineno = substitute(line, regex, line_replacement, '')
        call add(files, [fname, lineno])
      endif
    endfor
    if(!empty(files))
      return files
    endif
  endfor
endfunction "}}}

"{{{OpenStackTrace(files) open extracted files in new tab
"files: [[file1, line1], [file2, line2] ... ] from a stacktrace
function! s:OpenStackTrace(files)
  "disable redraw when opening files
  "still redraws when a split occurs but might *slightly* improve performance
  let lazyredrawSet = &lazyredraw
  set lazyredraw
  tabnew
  if (g:unstack_showsigns)
    sign define errline text=>> linehl=Error texthl=Error
    "sign ID's should be unique. If you open a stack trace with 5 levels,
    "you'd have to wait 5 seconds before opening another or risk signs
    "colliding.
    let signId = localtime()
    let t:unstack_tabId = signId
    let s:unstack_signs[t:unstack_tabId] = []
  endif
  for fileinfo in a:files
    let filepath = fileinfo[0]
    let lineno = fileinfo[1]
    exe "edit ".filepath
    "move line with error to top then show 5 lines of context above
    setl scrolloff=5
    exe "normal! " . lineno . "z+"
    if (g:unstack_showsigns)
      exe "sign place " . signId . " line=" . lineno . " name=errline buffer=" . bufnr('%')
      call add(s:unstack_signs[t:unstack_tabId], signId)
      let signId += 1
    endif
    "make a new vertical split for the next file
    botright vnew
  endfor
  "after adding the last file, the loop above calls vnew again.
  "delete this last empty vertical split
  exe 'quit'
  if (!lazyredrawSet)
    set nolazyredraw
  endif
endfunction "}}}

"{{{s:RemoveSigns(tabId) remove signs from the files initially opened in a tab
function! s:RemoveSigns(tabId)
  for signId in s:unstack_signs[a:tabId]
    exe "sign unplace " . signId
  endfor
  unlet s:unstack_signs[a:tabId]
endfunction "}}}

"{{{s:GetOpenTabIds() get unstack id's for current tabs
function! s:GetOpenTabIds()
  let curTab = tabpagenr()
  "determine currently open tabs
  let openTabIds = []
  tabdo if exists('t:unstack_tabId') | call add(openTabIds, string(t:unstack_tabId)) | endif
  "jump back to prev. tab
  exe "tabnext " . curTab 
  return openTabIds
endfunction "}}}

"{{{s:RemoveSignsFromClosedTabs() remove signs that were placed in tabs that are
"now closed
function! s:RemoveSignsFromClosedTabs()
  let openTabIds = s:GetOpenTabIds()
  for tabId in keys(s:unstack_signs)
    if index(openTabIds, tabId) == -1
      call s:RemoveSigns(tabId)
    endif
  endfor
endfunction "}}}

" vim:set foldmethod=marker
