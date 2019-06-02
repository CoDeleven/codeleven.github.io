assume cs:codesg

codesg segment
start:
    ; 将do0移到0:200
    mov ax, cs
    mov ds, ax
    mov si, offset do0
    
    mov ax, 0
    mov es, ax
    mov di, 200H
    
    mov cx, offset end_do0 - offset do0
    cld
    
    rep movsb
    
    ; 设置中断向量表
    mov ax, 0
    mov ds, ax
    mov ax, 200H
    mov ds:[0], ax
    mov ax, 0H
    mov ds:[2], ax
    
    mov ax, 10
    mov dx, 1
    mov cx, 0
    div cx
    
    ; 如果div是正常的就直接结束
    mov ax, 4c00H
    int 21H
do0:
   str:
   jmp short do0_start
   db 'invalide div'
   do0_start:
   push si
   push ax
   push ds
   push es
   mov ax, 0
   mov ds, ax
   mov ax, 0B800H
   mov es, ax
   mov si, 202H
   mov di, 0
   mov cx, 12
   s:
   mov al, [si]
   mov ah, 2
   
   mov es:[di], ax
   inc si
   add di, 2
   loop s
   pop es
   pop ds
   pop di
   pop si
   
   ; 如果这里直接使用iret，是直接回到被中断的地方
   ; 如果遇到div，发生除法溢出被中断了，中断程序结束后还是会回到div处
   mov ax, 4c00H
   int 21H
   end_do0:
   nop
codesg ends
end start