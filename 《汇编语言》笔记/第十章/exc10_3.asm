assume cs:codesg, ds:data

data segment
    db 10 dup (0)
data ends

codesg segment

start:
    ; mov ax, 12666
    ; mov bx, data
    ; mov ds, bx
    ; mov si, 0

    mov ax, 0FFFEH
    mov bl, 10
    div bl

    mov ax, 4c00h
    int 21h
    ;call dtoc

    ; mov dh, 8
    ; mov dl, 3
    ; mov cl, 2

    ; call show_str


dtoc:
    push ax
    push dx
    mov cx, ax

    ; save constant 10
    mov bl, 10

    div bl
    ; ah is char
    add ah, 30H
    mov [si], ah

    mov ax, ah
    inc si


codesg ends
    
end start