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
    db 21 dup ('year        0       0       0', 0)
table ends

stack segment
    db 20 dup (0)
stack ends

codesg segment
start:
    ; 设置数据段
    mov ax, data
    mov ds, ax
    ; 设置栈
    mov ax, stack
    mov ss, ax
    mov sp, 20
    ; 设置中间段
    mov ax, table
    mov es, ax

    mov bp, 0
    mov di, 0
    mov cx, 21
    mov si, 0
s:
    ; 年份处理，直接放入中间段中
    mov ax, ds:[si + bp+ 0]
    mov es:[di + 0], ax
    mov ax, ds:[si + bp + 2]
    mov es:[di + 2], ax

    ; 收入处理，因为收入是数值，并非ascii，所以先要进行dtoc处理
    mov ax, ds:[si + bp + 84]
    mov dx, ds:[si + bp + 86]

    call dtoc


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

dtoc:
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    

s1:
    mov cx, 10
    ; ax 为dword的低16位；dx 为dowrd的高16位；cx为除数
    call divdw
    
    ; ah is char
    add dx, 30H
    push dx
    ; mov [si], dx
    
    inc si
    mov cx, ax
    jcxz end_dtoc
    
    jmp short s1

end_dtoc:
    mov di, 0
    mov cx, si
s2:
    pop ax
    mov [di], ax
    inc di
    loop s2

    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

divdw:
    push ax
    push bx
    push cx
    ; 由于先要计算高位，所以先把低位存起来
    push ax
    ; 把高位放在ax里，因为int(H / n) * 65535，这里的65535代表结果要乘以10000H，表示放在高位上
    mov ax, bx
    mov dx, 0
    ; 除完后，ax保存商，dx保存余数
    div cx
    ; 因为ax寄存器还有用处，ax暂存到bx里面
    mov bx, ax
    ; 恢复原来的ax
    pop ax
    ; 此时dx里保存着余数，dx在计算时放在高位，隐式乘上65535，ax里保存低位，加在一起就是 dx * 65535 + ax
    ; 除以n
    div cx

    mov cx, dx
    mov dx, bx

    pop cx
    pop bx
    pop ax

    ret

codesg ends

end start