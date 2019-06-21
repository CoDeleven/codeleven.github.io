assume cs:codesg, ds:data

data segment
    db 9, 8, 7, 4, 2, 0
    db "00/00/00 00:00:00$"
data ends

codesg segment

start:
    mov ax, data
    mov ds, ax

    mov si, 0
    mov di, 0
    mov cx, 6
l:
    push cx

    ; 读取内存单元位置
    mov bl, [si]
    ; 设置参数
    mov al, bl
    call readCMOS_RAM

    ;al 保存的取出来的数值
    mov ah, al
    mov cl, 4
    shr ah, cl
    and al, 00001111b

    pop cx

    add al, 30H
    add ah, 30H

    ; 保存十位数
    mov [di + 6], ah
    inc di
    ; 保存个位数
    mov [di + 6], al
    inc di

    mov dl, [di + 6]
    cmp dl, 47
    je skip_char
    cmp dl, 32
    je skip_char
    cmp dl, 58
    je skip_char

normal:
    inc si
    loop l
    jmp end_program

skip_char:
    inc di
    jmp normal

end_program:
    mov ax, data
    mov ds, ax
    mov ah, 09H
    mov dx, 6
    int 21H

    mov ax, 4c00H
    int 21H

; 参数：  al 保存欲读取的内存单元位置
; 返回值：al 对应内存单元的数值
readCMOS_RAM:
    out 70h, al
    in al, 71H

    ret

codesg ends

end start