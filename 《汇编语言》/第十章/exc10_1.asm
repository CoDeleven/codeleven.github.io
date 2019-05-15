assume cs:codesg, ds:data

data segment
    db 'Welcome to masm!',0
data ends

codesg segment

start:
    mov dh, 11
    mov dl, 32
    mov cl, 2
    mov ax, data
    mov ds, ax
    mov si, 0

    call show_str

    mov ax, 4c00h
    int 21h

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
 s:
    mov cl, [si]
    mov ch, 0
    jcxz show_str_end
    mov ch, al
    mov es:[di], cx
    inc si
    add di, 2
    jmp s
    
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