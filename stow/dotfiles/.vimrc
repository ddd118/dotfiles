set nocompatible
syntax enable
filetype plugin indent on
let g:sh_indent_case_labels=1
set number
set hlsearch
set incsearch
set ignorecase
set smartcase
set title
set ambiwidth=double
set tabstop=4
set expandtab
set shiftwidth=4
set autoindent
set smartindent
set list
set nrformats-=octal
set hidden
set history=50
set virtualedit=block
set backspace=indent,eol,start
set wildmenu

" --- vim-plug ---
call plug#begin('~/.vim/plugged')
" Plugin List
Plug 'dense-analysis/ale'

call plug#end()

" --- ALE: shellcheck + shfmt ---
let g:ale_linters = { 'sh': ['shellcheck'] }
let g:ale_fixers  = { 'sh': ['shfmt'] }
let g:ale_fix_on_save = 1

let g:ale_sign_error = '✗'
let g:ale_sign_warning = '⚠'
let g:ale_echo_msg_format = '[%linter%] %s'

