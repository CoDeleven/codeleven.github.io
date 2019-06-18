assume cs:code, ds:data

data segment
    db "welcome to masm! ", 0
data ends

code segment 
start: 
    ; 设置起点
    mov ax, cs
    mov ds, ax
    mov si, offset show_str
    ; 设置循环次数
    mov cx, offset end_show_str - offset show_str
    ; 设置复制的目标地
    mov ax, 0
    mov es, ax
    mov di, 200
    ; 设置复制方向
    cld
    ; 执行复制
    rep movsb

    mov bx, 1F0H
    ; 设置中断向量表
    ; 设置ip
    mov byte ptr es:[1F0H], 200
    ; 设置cs
    mov byte ptr es:[1F2H], 0

    ; 想试试中断是不是就永远留在了系统中，所以先安装7CH中断例程，再运行程序看看
    ; mov dh, 10
    ; mov dl, 10
    ; mov cl, 2
    ; mov ax, data
    ; mov ds, ax
    ; mov si, 0
    ; int 7cH

    mov ax, 4c00H
    int 21H
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
    mov di, ax

    mov bl, cl
    mov ch, 0
s:
    mov cl, ds:[si]
    jcxz after_show_str

    mov al, cl
    mov ah, bl

    mov es:[di], ax

    inc si
    inc di
    inc di

    loop s
after_show_str:
    pop di
    pop si
    pop es
    pop dx
    pop cx
    pop bx
    pop ax
    iret
end_show_str:
    nop

code ends

end start