assume cs:codesg, ds:data

data segment
    db 10 dup (0)
data ends

codesg segment

start:
    mov ax, 12666
    mov bx, data
    mov ds, bx
    mov si, 0

    call dtoc

    mov dh, 8
    mov dl, 3
    mov cl, 2

    call show_str

    mov ax, 4c00h
    int 21h

dtoc:
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    mov bx, 10

s:
    mov dx, 0
    ; save constant 10
    div bx

    ; ah is char
    add dx, 30H
    push dx
    ; mov [si], dx
    
    inc si
    mov cx, ax
    jcxz end_dtoc
    
    jmp short s

end_dtoc:
    mov di, 0
    mov cx, si
s0:
    pop ax
    mov [di], ax
    inc di
    loop s0

    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

show_str:
    ; save reg
    push ax
    push cx
    push dx
    push si
    push di
    push es
    
    mov ax, 0B800H
    mov es, ax

    mov al, 0A0H
    ; calculate row
    mul dh
    ; save row
    mov di, ax

    mov al, 02H
    ; calculate column
    mul dl
    ; save column
    add di, ax

    ; save char attribute
    mov al, cl
 s2:
    mov cl, [si]
    mov ch, 0
    jcxz show_str_end
    mov ch, al
    mov es:[di], cx
    inc si
    add di, 2
    jmp s2
    
show_str_end:
    pop es
    pop di
    pop si
    pop dx
    pop cx
    pop ax
    ret

codesg ends
    
end start