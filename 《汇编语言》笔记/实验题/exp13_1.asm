assume cs:code

code segment 
start: 

show_str:
    push ax
    push bx
    push cx
    push dx
    push es
    push si
    push di

    ; 获得 行
    mov ax, 0A0H
    mul dh
    mov bx, ax

    ; 获得 列
    mov ax, 2H
    mul dl
    ; 将行号和列号加在一起
    add ax, bx

    ; 设置段寄存器
    mov di, 0B800H
    mov es, di

    mov bl, cl
s:
    mov cx, ds:[si]
    mov ch, 0
    jcxz end_show_str

    mov al, cl
    mov ah, bl

    mov es:[di], ax

    inc si
    inc di
    inc di

    loop s
end_show_str:
    pop di
    pop si
    pop es
    pop dx
    pop cx
    pop bx
    pop ax
    iret

code ends

end start