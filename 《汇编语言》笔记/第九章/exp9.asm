assume ds:data, cs:codesg

data segment
    db 'welcome to masm!'
data ends

codesg segment

start:
    mov ax, data
    ; save data
    mov es, ax
    mov ax, 0B000H
    ; show to screen
    mov ds, ax

    mov si, 0
    mov di, 86E0H
    mov cx, 16
green: 
     mov bl, es:[si]
     mov bh, 00000010B
     mov [di + 64], bx
     add di, 2
     inc si
     loop green

     mov si, 0
     mov di, 8780H
     mov cx, 16
foo: 
    mov bl, es:[si]
    mov bh, 11000010B
    mov [di + 64], bx
    add di, 2
    inc si
    loop foo

     mov si, 0
     mov di, 8820H
     mov cx, 16
bar: 
    mov bl, es:[si]
    mov bh, 00000111B
    mov [di + 64], bx
    add di, 2
    inc si
    loop bar


    mov ax, 4c00h
    int 21h
    
codesg ends

end start