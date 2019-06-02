assume cs:codesg, ds:datasg
; 编写一个子程序，将包含任意字符，以0结尾的字符串中的小写字母[97~122]转变成大写字母
datasg segment
    db "Beginner's All-purpose Symbolic Instruction Code.",0
datasg ends

codesg segment
start:    
    mov ax, datasg
    mov ds, ax
    mov si, 0
    call letterc

    mov ax, 4c00H
    int 21H
letterc:
    mov bx, 0
s0:    
    mov ax, [bx]
    mov ah, 0
    mov cx, ax
    cmp ax, 97
    jb s
    cmp ax, 122
    ja s
    ; 执行小写转大写
    and ax, 11011111B
    mov byte ptr [bx], al
s:
    add bx, 1
    jcxz letterc_end
    loop s0
letterc_end:
    ret

codesg ends

end start