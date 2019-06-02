assume cs:codesg, ds:data

data segment
    db 10 dup (0)
data ends

codesg segment

start:
    mov ax, 4240H
    mov dx, 000FH
    mov cx, 0AH
    ; X/n = int(H/n)×65536+[rem(H/n)*65536+L]/n
    call divdw

    mov ax, 4c00h
    int 21h

divdw:
    push bx
    ; 由于先要计算高位，所以先把低位存起来
    push ax
    ; 把高位放在ax里，因为int(H / n) * 65535，这里的65535代表结果要乘以10000H，表示放在高位上
    mov ax, dx
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

    pop bx

    ret
codesg ends
    
end start