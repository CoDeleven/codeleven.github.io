assume cs:codesg

data segment
    db '1975','1976', '1977', '1978', '1979', '1980', '1981', '1982', '1983'
    db '1984', '1985', '1986', '1987', '1988', '1989', '1990', '1991', '1992'
    db '1993', '1994', '1995'
    ; 21个数据，保存年份，0~83,

    dd 16, 22, 382, 1356, 2390, 8000, 16000, 24486, 50065, 97479, 140417, 197514
    dd 345980, 590827, 803530, 1183000, 1843000, 2759000, 3753000, 4649000, 59370000
    ; 21个数据，保存收入，84~ 167，每次递增4

    dw 3, 7, 9, 13, 28, 38, 130, 220, 476, 778, 1001, 1442, 2258, 2793, 4037, 5635, 8226
    dw 11542, 14430, 15257, 17800
    ; 21个数据，保存人数，168~210, 每次递增2
data ends

table segment
    db 21 dup ('year sumn ne ?? ')
table ends

codesg segment
start:
    mov ax, data
    mov ds, ax

    mov ax, table
    mov es, ax

    mov bp, 0
    mov di, 0
    mov cx, 21
    mov si, 0
s:
    mov ax, ds:[si + bp+ 0]
    mov es:[di + 0], ax
    mov ax, ds:[si + bp + 2]
    mov es:[di + 2], ax

    mov ax, ' '
    mov es:[di + 4], ax

    mov ax, ds:[si + bp + 84]
    mov es:[di + 5], ax
    mov ax, ds:[si + bp + 86]
    mov es:[di + 7], ax

    mov ax, ' '
    mov es:[di + 9], ax

    mov ax, ds:[si + 168]
    mov es:[di + 0AH], ax

    mov ax, ' '
    mov es:[di + 0CH], ax

    mov ax, ds:[si + bp + 84]
    mov dx, ds:[si + bp + 86]
    div word ptr ds:[si + 168]

    mov es:[di + 0DH], ax

    add bp, 2
    add si, 2
    add di, 010H
    loop s

codesg ends

end start