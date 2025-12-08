# 让 Ctrl+左右箭头、Alt+b/f 按 shell 语法跳词（跳变量、路径、引号内等）
autoload -U select-word-style
select-word-style bash   # 或者试试 'normal'、'shell'
