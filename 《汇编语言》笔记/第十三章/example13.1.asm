assume cs:code

code segment 
start: 
    ; 设置起点
    mov ax, cs
    mov ds, ax
    mov si, offset mock_loop
    ; 设置循环次数
    mov cx, offset end_i - offset mock_loop
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
    
    mov ax, 0b800H
    mov es, ax
    mov di, 160 * 12
    mov bx, offset s - offset se
    mov cx, 80

s:  mov byte ptr es:[di], '!'
    add di, 2
    int 7ch
se:
    nop
    
    mov ax, 4c00h
    int 21h

mock_loop:
    ; 这里用到了bp，把bp压入栈
    push bp
    ; 将栈顶位置赋给bp
    mov bp, sp 
    ; 递减cx
    dec cx
    ; 如果cx为0则执教跳转到end_mock_loop并返回原来的程序
    jcxz end_mock_loop
    add [bp + 2], bx

end_mock_loop:
    pop bp
    iret
end_i:
    nop

code ends

end start