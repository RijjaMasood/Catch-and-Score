[org 0x0100]
jmp start
GameOver: db 0
rannum: dw 0
startmessage: db 'Press Enter to Start' , 0
scoremessage: db '   Your Score is:' , 0
tnt: db 'T N T' , 0
timep: db 'TIME LEFT : ',0
liveScore: db 'SCORE :',0
somedelay: dw 1
bpos: dw 70 ;basket position
tickcount: dw 0
sec: dw 120
oldtimerisr: dd 0
oldkbisr: dd 0
score: dw 0
currentElementsinINFO: db 0
maximumElementsinINFO equ 10
info: dd 0,0,0,0,0,0,0,0,0,0 ; = 40 bytes

;   info   info+1  info+2       info+3
; [SWITCH][Column] [Row]   [TYPE, 1,2,3,4]
; each object has 4 bytes allocated
; so for traversing through objects (info) we would add +4 in the index/pointer register
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
random_gen:
    push bp
    mov bp, sp
    push ax
    push bx
    push cx
    push dx
    ; mov ax, word[rannum]
    ; inc ax
    ; mov word[rannum], ax
    rdtsc
    xor dx,dx
    mov cx, [bp+4]
    div cx
    mov byte[rannum], dl

    pop dx
    pop cx
    pop bx
    pop ax
    pop bp
    ret 2
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; timer interrupt service routine
timer:
    push ax
    push bx
    push cx
    push dx
    push di
    inc word [cs:tickcount]; increment tick count

    cmp word [cs:tickcount], 18; increment tick count
    jne td
    call generate
    ;;update all objects pos here
    mov cx, maximumElementsinINFO
    mov di, -1*4
    Object_loop:
        add di, 1*4
        mov al, byte[info+di]
        cmp al, 0
    je Object_loop_next
    
    add byte[info+di+2], 1 ; 
    xor ax, ax
    mov al, byte[info+di+2] ; row
    push ax
    mov al, byte[info+di+1] ; column
    push ax
    mov al, byte[info+di+3] ; checking for the type/category
    cmp al, 1
    jne Object_loop_c1
    call bomb
    jmp Object_loop_next
    Object_loop_c1:
    cmp al, 2
    jne Object_loop_c2
    call coin15print
    jmp Object_loop_next
    Object_loop_c2:
    cmp al, 3
    jne Object_loop_c3
    call coin10print
    jmp Object_loop_next
    Object_loop_c3:
    call coin5print
    Object_loop_next: loop Object_loop
    
    call Object_Collision

    mov byte[cs:tickcount],0
    cmp word [cs:sec], 0
    je td
    dec word[cs:sec]
    td:
    mov ax,[cs:sec]
    mov dl,60
    div dl

    mov dx,160*1+26
    push dx
    mov dh,0
    mov dl,al
    push dx
    call printnum ; print tick count

    push es
    push ax
    mov ax, 0xb800
    mov es,ax
    mov ah,0xF0
    mov al,':'
    mov word[es:160*1+28],ax
    mov ah,0x70
    mov al,' '
    mov word[es:160*1+32],ax
    pop ax
    pop es

    mov dx,160*1+30
    push dx
    mov dh,0
    mov dl,ah
    push dx
    call printnum ; print tick count

    mov ax,160*1+152
    push ax
    push word[score]
    call printnum

    mov al, 0x20
    out 0x20, al ; end of interrupt
    pop di
    pop dx
    pop cx
    pop bx
    pop ax
    iret ; return from interrupt

check_collision:
    push bp
    mov bp,sp
    push ax
    xor dx, dx
    ; O1 is up; O2 is down
    ;
    ;   1 2
    ;   3 4
    ;
            ;bp+14	x1
            ;bp+12	x1+Length
            ;bp+10	x2
            ;bp+8	x2+Length
            ;bp+6	y1+H
            ;bp+4	y2
    mov ax, [bp+12]
    cmp ax, [bp+10]
    jl collision_end ;
    mov ax, [bp+8]
    cmp ax, [bp+14]
    jl collision_end ;
    mov ax, [bp+6]
    cmp ax, [bp+4]
    jl collision_end ;

    mov dx, 1 ; collision detected
    collision_end:
    pop ax
    pop bp
    ret 12

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
generate:
    push di
    push ax
    push bx
    cmp byte[currentElementsinINFO], maximumElementsinINFO
    je generate_exit
    xor di,di
    gen_findloc:
    cmp byte[info+di], 0
    je gen_findloc_break
    add di, 1*4
    cmp di, maximumElementsinINFO*4
    jne gen_findloc
    gen_findloc_break:
    mov ax, 2
    push ax
    call random_gen
    mov ax, word[rannum]
    cmp ax, 0
    je generate_exit
    ; IF Random number was 0, object is not created...
    mov byte[info+di], al ; Range 0 and 1 = toggle
    mov ax, 4
    push ax
    call random_gen
    mov ax, word[rannum]
    inc ax
    mov byte[info+di+3], al ;Range 1-4 = type/category
    mov ax, 70
    push ax
    call random_gen
    mov ax, word[rannum]
    inc ax
    shl ax, 1
    mov byte[info+di+1], al ; Range 1-70 = column
    mov byte[info+di+2], 2 ; row
    add byte[currentElementsinINFO], 1
    generate_exit:
    pop bx
    pop ax
    pop di
    ret
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
Object_Collision:
    push bp
    push es
    push ax
    push bx
    push cx
    push dx
    push di
    push si
    mov ax, 0xb800
    mov es, ax

   ;--------------------- For Ground -------------------------
    xor ax, ax
    mov cx, maximumElementsinINFO
    mov si, -1*4
    D_Object_loop:
    add si, 1*4
       mov al, byte[info+si]
    cmp al, 0
    je D_Object_loop_next
    xor ax, ax
    mov al, byte[info+si+1]
        push ax
    add al, 4           
        push ax
    mov al, 0
        push ax
    mov ax, 158
        push ax
    xor ax, ax
    mov al, byte[info+si+2]
    add al, 2
        push ax
    mov al, 21
        push ax
    call check_collision ; This collision has no rule of x-component

    cmp dx, 0
    je D_Object_loop_next
    
    mov byte[info+si], 0
    dec byte[currentElementsinINFO]
    
    xor ax, ax
    mov al, byte[info+si+2]
    push ax
    mov al, byte[info+si+1]
    push ax
    mov al, byte[info+si+3]
                            cmp al, 1
    jne Type_STAR_1
        call delbombalt
    jmp D_Object_loop_next
    Type_STAR_1:
        call delstar
    D_Object_loop_next: loop D_Object_loop
   ;--------------------- For PLAYER ---------------------------
    xor ax, ax
    mov cx, maximumElementsinINFO
    mov si, -1*4
    D_Object_loop1:
    add si, 1*4
       mov al, byte[info+si]
    cmp al, 0
    je D_Object_loop_next1
    xor ax, ax
    mov al, byte[info+si+1] ;column
        push ax
    add al, 12 
    cmp byte[info+si+3], 1
        jne PUSHData
        sub ax, 4
    PUSHData:  push ax
    mov ax, word[bpos]
        push ax 
    add ax, 18
        push ax 
    xor ax, ax
    mov al, byte[info+si+2] ;row
    add al, 2
        push ax
    mov al, 18
        push ax
    call check_collision ; This collision has no rule of x-component

    cmp dx, 0
    je D_Object_loop_next1
    
    mov byte[info+si], 0
    dec byte[currentElementsinINFO]

    xor ax, ax
    mov al, byte[info+si+2]
    push ax
    mov al, byte[info+si+1]
    push ax
     mov al, byte[info+si+3]
                            cmp al, 1
    jne Type_15STAR
        call delbombalt
        mov byte[GameOver], 1; PROGRAM TERMINATION
    jmp D_Object_loop_next1
    Type_15STAR:            call delstar
                            cmp al, 2
    jne Type_10STAR
    add word[score], 15
    jmp D_Object_loop_next1
    Type_10STAR:            cmp al, 3
    jne Type_05STAR
    add word[score], 10
    jmp D_Object_loop_next1
    Type_05STAR:
        add word[score], 5
    D_Object_loop_next1: 
        dec cx
        jz D_Object_loop_END
        jmp D_Object_loop1
    D_Object_loop_END:
    pop si
    pop di
    pop dx
    pop cx
    pop bx
    pop ax
    pop es
    pop bp
    ret
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
func:
    push bp
    mov bp,sp
    push ax
    push cx
    l1:
    cmp word[bp+4],0
    je last
    mov ax,0x002d
    l2:
    mov cx,0xffff
    l3:
    loop l3
    dec ax
    jnz l2
    dec word[bp+4]
    jmp l1
    last:
    pop cx
    pop ax
    pop bp
    ret 2
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
clrscr:
    push es
    push ax
    push di
    mov ax, 0xb800
    mov es, ax ; point es to video base
    mov di, 0 ; point di to top left column
    nextloc:
    mov word [es:di], 0x0720 ; clear next char on screen
    add di, 2 ; move to next screen location
    cmp di, 4000 ; has the whole screen cleared
    jne nextloc ; if no clear next position
    pop di
    pop ax
    pop es
    ret
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
printnum:
    push bp
    mov bp, sp
    push es
    push ax
    push bx
    push cx
    push dx
    push di
    mov ax, 0xb800
    mov es, ax ; point es to video base
    mov ax, [bp+4] ; load number in ax
    mov bx, 10 ; use base 10 for division
    mov cx, 0 ; initialize count of digits
    nextdigit:
    mov dx, 0 ; zero upper half of dividend
    div bx ; divide by 10
    add dl, 0x30 ; convert digit into ascii value
    push dx ; save ascii value on stack
    inc cx ; increment count of values
    cmp ax, 0 ; is the quotient zero
    jnz nextdigit ; if no divide it again
    mov di, [bp+6]                   ; 160*1+26  
    nextpos: pop dx ; remove a digit from the stack
    mov dh, 0x70 ; use normal attribute
    mov [es:di], dx ; print char on screen
    add di, 2 ; move to next screen location
    loop nextpos ; repeat for all digits on stack
    pop di
    pop dx
    pop cx
    pop bx
    pop ax
    pop es
    pop bp
    ret 4
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
printsky:
    push es
    push ax
    push di
    mov ax, 0xb800
    mov es, ax ; point es to video base
    mov di, 0 ; point di to top left column
    ln:
    mov word [es:di], 0x7020 ; clear next char on screen
    add di, 2 ; move to next screen location
    cmp di, 3520 ; has the whole screen cleared
    jne ln ; if no clear nfext position
    nextw:
    mov word [es:di], 0x4020 ; clear next char on screen
    add di, 2 ; move to next screen location
    cmp di, 4000 ; has the whole screen cleared
    jne nextw ; if no clear next position

    ;----Live Score print-------
    push es
    push di
    push ds
    pop es
    xor al, al
    mov di, liveScore
    mov cx, 0xFFFF
    repne scasb
    mov ax, 0xFFFF
    sub ax, cx
    xchg ax, cx
    dec cx
    pop di
    pop es

    mov ah, 0x70
    mov di, 160*1 + 134 ; point di to top left column
    mov si, liveScore
    ln4:
    lodsb
    stosw
    loop ln4

    ;----time print-------
    push es
    push di
    push ds
    pop es
    xor al, al
    mov di, timep
    mov cx, 0xffff
    repne scasb
    mov ax, 0xffff
    sub ax, cx
    xchg ax, cx
    dec cx
    pop di
    pop es


    mov ah, 0x70
    mov di, 160*1 + 2 ; point di to top left column
    mov si, timep
    ln3:
    lodsb
    stosw
    loop ln3
    pop di
    pop ax
    pop es
    ret
 ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
coin15print:
    push bp
    mov bp, sp
    push es
    push ax
    push bx
    push cx
    push dx
    push di
    mov ax, 0xb800
    mov es, ax ; point es to video base

    ;;-----ball 1 thing 15 points--------
    ;;removing old
   mov ax,160
    mov dx, word[bp+6]
    sub dx,1
    mul dx
    add ax,word[bp+4]
    mov di,ax
    mov ax, 0x7020
    mov cx, 7
    rep stosw
    
    mov ax,160
    mov dx, word[bp+6]
    mul dx
    add ax,word[bp+4]
    mov di,ax
    mov ax, 0x7020
    stosw
    add di, 2
    stosw
    add di, 2
    stosw
    add di, 2
    stosw

    mov ax,160
    mov dx, word[bp+6]
    inc dx
    mul dx
    add ax,word[bp+4]
    mov di,ax
    add di, 2
    mov ax, 0x7020
    stosw
    add di, 2
    stosw
    add di, 2
    stosw

     ;new updation
    ;mov di, 160*4 + 88 ; point di to top left column
    mov ax,160
    mov dx, word[bp+6]
    mul dx
    add ax,word[bp+4]
    mov di,ax
    add di, 2
    mov al,'/'
    mov ah,0x71
    mov cx,1
    rep stosw
    add di,2
    mov al,'#'
    mov ah,0x71
    mov cx,1
    rep stosw
    add di,2
    mov al,'\'
    mov ah,0x71
    mov cx,1
    rep stosw

    ;mov di, 160*5 + 86 ; point di to top left column
    mov ax,160
    mov dx, word[bp+6]
    add dx,1
    mul dx
    add ax,word[bp+4]
    mov di,ax
    mov ah,0x71
    mov al,'#'
    mov cx,1
    rep stosw
    add di,2
    mov ah,0x7E
    mov al,'1'
    mov cx,1
    rep stosw
    add di,2
    mov ah,0x7E
    mov al,'5'
    mov cx,1
    rep stosw
    add di,2
    mov ah,0x71
    mov al,'#'
    mov cx,1
    rep stosw
    ;;;;;;;;;;;;;;;;;

    ;mov di, 160*6 + 88 ; point di to top left column
    mov ax,160
    mov dx, word[bp+6]
    add dx,2
    mul dx
    add ax,word[bp+4]
    mov di,ax
    add di, 2
    mov al,'\'
    mov ah,0x71
    mov cx,1
    rep stosw

    add di,2
    mov al,'#'
    mov ah,0x71
    mov cx,1
    rep stosw
    add di,2
    mov al,'/'
    mov ah,0x71
    mov cx,1
    rep stosw
    pop di
    pop dx
    pop cx
    pop bx
    pop ax
    pop es
    pop bp
    ret 4  
coin10print:
    push bp
    mov bp, sp
    push es
    push ax
    push bx
    push cx
    push dx
    push di
    mov ax, 0xb800
    mov es, ax ; point es to video base
    
        ;  / # \          
        ; # 1 0 #  / # \
        ;  \ # /  # 1 0 #  
        ;          \ # /

    ;;-----ball 1 thing 15 points--------
    ;;removing old
    mov ax,160
    mov dx, word[bp+6]
    sub dx,1
    mul dx
    add ax,word[bp+4]
    mov di,ax
    mov ax, 0x7020
    mov cx, 7
    rep stosw
    
    mov ax,160
    mov dx, word[bp+6]
    mul dx
    add ax,word[bp+4]
    mov di,ax
    mov ax, 0x7020
    stosw
    add di, 2
    stosw
    add di, 2
    stosw
    add di, 2
    stosw

    mov ax,160
    mov dx, word[bp+6]
    inc dx
    mul dx
    add ax,word[bp+4]
    mov di,ax
    add di, 2
    mov ax, 0x7020
    stosw
    add di, 2
    stosw
    add di, 2
    stosw


    ;new updation
    ;mov di, 160*4 + 88 ; point di to top left column
    mov ax,160
    mov dx, word[bp+6]
    mul dx
    add ax,word[bp+4]
    mov di,ax
    add di, 2 
    mov al,'/'
    mov ah,0x71
    mov cx,1
    rep stosw
    add di,2
    mov al,'#'
    mov ah,0x71
    mov cx,1
    rep stosw
    add di,2
    mov al,'\'
    mov ah,0x71
    mov cx,1
    rep stosw
    
    ;mov di, 160*5 + 86 ; point di to top left column
    mov ax,160
    mov dx, word[bp+6]
    add dx,1
    mul dx
    add ax,word[bp+4]
    mov di,ax
    mov ah,0x71
    mov al,'#'
    mov cx,1
    rep stosw
    add di,2
    mov ah,0x7E
    mov al,'1'
    mov cx,1
    rep stosw
    add di,2
    mov ah,0x7E
    mov al,'O'
    mov cx,1
    rep stosw
    add di,2
    mov ah,0x71
    mov al,'#'
    mov cx,1
    rep stosw
    ;;;;;;;;;;;;;;;;;
    
    ;mov di, 160*6 + 88 ; point di to top left column
    mov ax,160
    mov dx, word[bp+6]
    add dx,2
    mul dx
    add ax,word[bp+4]
    mov di,ax
    add di, 2    
    mov al,'\'
    mov ah,0x71
    mov cx,1
    rep stosw
    
    add di,2
    mov al,'#'
    mov ah,0x71
    mov cx,1
    rep stosw
    add di,2
    mov al,'/'
    mov ah,0x71
    mov cx,1
    rep stosw
    pop di
    pop dx
    pop cx
    pop bx
    pop ax
    pop es
    pop bp
    ret 4
coin5print:
    push bp
    mov bp, sp
    push es
    push ax
    push bx
    push cx
    push dx
    push di
    mov ax, 0xb800
    mov es, ax ; point es to video base

    ;;-----ball 1 thing 15 points--------
    ;;removing old
        mov ax,160
        mov dx, word[bp+6]
        sub dx,1
        mul dx
        add ax,word[bp+4]
        mov di,ax
        mov ax, 0x7020

        mov cx,7
        rep stosw
        
        ;mov di, 160*5 + 86 ; point di to top left column
        mov ax,160
        mov dx, word[bp+6]
        mul dx
        add ax,word[bp+4]
        mov di,ax
        mov ax, 0x7020
        stosw
        add di, 10
        stosw
        
        mov ax,160
        mov dx, word[bp+6]
        inc dx
        mul dx
        add ax,word[bp+4]
        mov di,ax
        add di, 2
        mov ax, 0x7020
        stosw
        add di, 6
        stosw
        
        ;;;;;;;;;;;;;;;;;

    ;new updation
    ;mov di, 160*4 + 88 ; point di to top left column
    mov ax,160
    mov dx, word[bp+6]
    mul dx
    add ax,word[bp+4]
    mov di,ax
    add di, 2
    mov al,'/'
    mov ah,0x71
    mov cx,1
    rep stosw
    add di,2
    mov al,'#'
    mov ah,0x71
    mov cx,1
    rep stosw
    add di,2
    mov al,'\'
    mov ah,0x71
    mov cx,1
    rep stosw

    ;mov di, 160*5 + 86 ; point di to top left column
    mov ax,160
    mov dx, word[bp+6]
    add dx,1
    mul dx
    add ax,word[bp+4]
    mov di,ax
    mov ah,0x71
    mov al,'#'
    mov cx,1
    rep stosw
    add di,4
    mov ah,0x7E
    mov al,'5'
    mov cx,1
    rep stosw
    add di,4
    mov ah,0x71
    mov al,'#'
    mov cx,1
    rep stosw
    ;;;;;;;;;;;;;;;;;

    ;mov di, 160*6 + 88 ; point di to top left column
    mov ax,160
    mov dx, word[bp+6]
    add dx,2
    mul dx
    add ax,word[bp+4]
    mov di,ax
    add di, 2
    mov al,'\'
    mov ah,0x71
    mov cx,1
    rep stosw

    add di,2
    mov al,'#'
    mov ah,0x71
    mov cx,1
    rep stosw
    add di,2
    mov al,'/'
    mov ah,0x71
    mov cx,1
    rep stosw
    pop di
    pop dx
    pop cx
    pop bx
    pop ax
    pop es
    pop bp
    ret 4
bomb:
    push bp
    mov bp, sp
    push es
    push ax
    push bx
    push cx
    push dx
    push di
    mov ax, 0xb800
    mov es, ax ; point es to video base
    ;-------old bomb--------
    ;----upper part of the bomb-------
    mov ax,160
    mov dx, word[bp+6]
    sub dx,2
    mul dx
    add ax, word[bp+4]
    mov di, ax
    mov ax, 0x7020
    mov cx,5
    rep stosw

    ;----TNT print-------

    mov ax,160
    mov dx, word[bp+6]
    sub dx,2

    add dx,1
    mul dx
    add ax, word[bp+4]
    mov di, ax
    mov ax, 0x7020
    mov cx,5
    rep stosw

    ;----lower part of the bomb-------
    mov ax,160
    mov dx, word[bp+6]
    sub dx,2

    add dx,2
    mul dx
    add ax, word[bp+4]
    mov di, ax
    mov ax, 0x7020
    mov cx,5
    rep stosw

    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; new
    ;----upper part of the bomb-------
    mov ax,160
    mov dx, word[bp+6]
    mul dx
    add ax,   word[bp+4]
    mov di, ax
    mov al,0x20
    mov ah,0x00
    mov cx,5
    rep stosw

    ;----TNT print-------
    push es
    push di
    push ds
    pop es
    xor al, al
    mov di, tnt
    mov cx, 0xFFFF
    repne scasb
    mov ax, 0xFFFF
    sub ax, cx
    xchg ax, cx
    dec cx
    pop di
    pop es

    mov ax,160
    mov dx, word[bp+6]
    add dx,1
    mul dx
    add ax,  word[bp+4]
    mov di, ax
    mov ah, 0x70
    mov si, tnt
    ln1:
    lodsb
    stosw
    loop ln1

    ;----lower part of the bomb-------
    mov ax,160
    mov dx, word[bp+6]
    add dx,2
    mul dx
    add ax,  word[bp+4]
    mov di, ax
    mov ax, 0x0020
    mov cx,5
    rep stosw
    pop di
    pop dx
    pop cx
    pop bx
    pop ax
    pop es
    pop bp
    ret 4
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
delstar:
    push bp
    mov bp, sp
     push es
    push ax
    push cx
    push dx
    push di
    mov ax, 0xb800
     mov es, ax ; point es to video base

     ;;removing old
     mov ax,160
     mov dx, word[bp+6]
     add dx, 1
     mul dx
     add ax,word[bp+4]
     mov di,ax
    mov ax, 0x7020
    mov cx,7
        rep stosw
     
     mov ax,160
     mov dx, word[bp+6]
     add dx, 2
     mul dx
     add ax,word[bp+4]
     mov di,ax
    mov ax, 0x7020
    mov cx,7
        rep stosw
     
     mov ax,160
     add dx, 3
     mov dx, word[bp+6]
     mul dx
     add ax,word[bp+4]
     mov di,ax
    mov ax, 0x7020
    mov cx,7
        rep stosw
     
     pop di
     pop dx
     pop cx
     pop ax
     pop es
     pop bp
     ret 4

 ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
delbombalt:
    push bp
    mov bp, sp
     push es
    push ax
    push cx
    push dx
    push di
    mov ax, 0xb800
     mov es, ax ; point es to video base
      ;-------old bomb--------
    ;----upper part of the bomb-------
     mov ax,160
     mov dx, word[bp+6]
     mul dx
     add ax,word[bp+4]
     mov di, ax
     mov ax, 0x7020
     mov cx,5
     rep stosw

    ;----TNT print-------

     mov ax,160
     mov dx, word[bp+6]
     add dx,1
     mul dx
     add ax,word[bp+4]
     mov di, ax
     mov ax, 0x7020
     mov cx,5
     rep stosw

    ;----lower part of the bomb-------
     mov ax,160
     mov dx, word[bp+6]
     add dx,2
     mul dx
     add ax,word[bp+4]
     mov di, ax
    mov ax, 0x7020
    mov cx,5
    rep stosw
     pop di
     pop dx
     pop cx
     pop ax
     pop es
     pop bp
     ret 4
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
startgame:
    push es
    push ax
    push di
    push cx
    mov ax, 0xb800
    mov es, ax ; point es to video base
    mov di, 0 ; point di to top left column
    nextloc1:
    mov word [es:di], 0xff20 ; clear next char on screen
    add di, 2 ; move to next screen location
    cmp di, 4000 ; has the whole screen cleared
    jne nextloc1 ; if no clear next position


    ;-------- 1 --------
    mov ax, 0xb800
    mov es, ax ; point es to video base
    mov ax, 0x4020
    mov di, 160*1 + 46 ; point di to top left column
    mov cx,6 ;;c
    rep stosw

    add di, 2 ;space
    mov cx,6 ;; a
    rep stosw

    add di, 2 ;space
    mov cx,6 ;; t
    rep stosw


    add di, 2 ;space
    mov cx,6 ;; c
    rep stosw

    add di, 2 ;space
    mov cx,2 ;; h
    rep stosw
    add di, 4 ;space
    mov cx, 2
    rep stosw

    ;--------2-----------

    mov di,160*2 + 46 ; point di to top left column
    mov cx,2 ;;c
    rep stosw

    add di, 10 ;space
    mov cx,2 ;; a
    rep stosw
    add di,4
    mov cx,2 ;; a
    rep stosw

    add di, 6 ;space
    mov cx,2 ;; t
    rep stosw


    add di, 6 ;space
    mov cx,2 ;; c
    rep stosw

    add di, 10 ;space
    mov cx,2 ;; h
    rep stosw
    add di, 4 ;space
    mov cx, 2
    rep stosw

    ;--------3-----------

    mov di,160*3 + 46 ; point di to top left column

    mov cx,2 ;;c
    rep stosw

    add di, 10 ;space
    mov cx,6 ;; a
    rep stosw

    add di, 6 ;space
    mov cx,2 ;; t
    rep stosw


    add di, 6 ;space
    mov cx,2 ;; c
    rep stosw

    add di, 10 ;space
    mov cx,6 ;; h
    rep stosw

    ;--------4-----------

    mov di,160*4 + 46; point di to top left column

    mov cx,2 ;;c
    rep stosw

    add di, 10 ;space
    mov cx,2 ;; a
    rep stosw
    add di,4
    mov cx,2 ;; a
    rep stosw

    add di, 6 ;space
    mov cx,2 ;; t
    rep stosw


    add di, 6 ;space
    mov cx,2 ;; c
    rep stosw

    add di, 10 ;space
    mov cx,2 ;; h
    rep stosw
    add di, 4 ;space
    mov cx, 2
    rep stosw

    ;--------5-----------

    mov di,160*5 + 46 ; point di to top left column

    mov cx,6 ;;c
    rep stosw

    add di, 2 ;space
    mov cx,2 ;; a
    rep stosw
    add di,4
    mov cx,2 ;; a
    rep stosw

    add di, 6 ;space
    mov cx,2 ;; t
    rep stosw


    add di, 6 ;space
    mov cx,6 ;; c
    rep stosw

    add di, 2 ;space
    mov cx,2 ;; h
    rep stosw
    add di, 4 ;space
    mov cx, 2
    rep stosw

    push word[somedelay]
    call func
    ;--------7-----------
    mov di,160*7 + 76 ; point di to top left column
    mov ah,0x47
    mov al, '&'
    mov word[es:di],0x4720
    mov word[es:di+2],ax
    mov word[es:di+4],0x4720

    push word[somedelay]
    call func
    ;--------9-----------
    mov al,20h
    mov di, 160*9 + 46 ; point di to top left column
    mov cx,6 ;;s
    rep stosw

    add di, 2 ;space
    mov cx,6 ;;c
    rep stosw

    add di, 2 ;space
    mov cx,6 ;; o
    rep stosw

    add di, 2 ;space
    mov cx,6 ;; r
    rep stosw


    add di, 2 ;space
    mov cx,6 ;; e
    rep stosw

    ;--------10-----------
    mov di, 160*10 + 46 ; point di to top left column
    mov cx,2 ;;s
    rep stosw

    add di, 10 ;space
    mov cx,2 ;;c
    rep stosw

    add di, 10 ;space
    mov cx,2 ;; o
    rep stosw
    add di, 4 ;space
    mov cx,2 ;; o
    rep stosw

    add di, 2 ;space
    mov cx,2 ;; r
    rep stosw
    add di, 4 ;space
    mov cx,2 ;; r
    rep stosw


    add di, 2 ;space
    mov cx,2 ;; e
    rep stosw

    ;--------11-----------
    mov di, 160*11 + 46 ; point di to top left column
    mov cx,6 ;;s
    rep stosw

    add di, 2 ;space
    mov cx,2 ;;c
    rep stosw

    add di, 10 ;space
    mov cx,2 ;; o
    rep stosw
    add di, 4 ;space
    mov cx,2 ;; o
    rep stosw

    add di, 2 ;space
    mov cx,4 ;; r
    rep stosw

    add di, 6 ;space
    mov cx,6;; e
    rep stosw

    ;--------12-----------
    mov di, 160*12 + 46 ; point di to top left column
    add di, 8 ;space
    mov cx,2 ;;s
    rep stosw

    add di, 2 ;space
    mov cx,2 ;;c
    rep stosw

    add di, 10 ;space
    mov cx,2 ;; o
    rep stosw
    add di, 4 ;space
    mov cx,2 ;; o
    rep stosw

    add di, 2 ;space
    mov cx,2 ;; r
    rep stosw
    add di, 4 ;space
    mov cx, 2
    rep stosw

    add di, 2 ;space
    mov cx,2;; e
    rep stosw

    ;--------13-----------
    mov di, 160*13 + 46 ; point di to top left column
    mov cx,6 ;;s
    rep stosw

    add di, 2 ;space
    mov cx,6 ;;c
    rep stosw

    add di, 2 ;space
    mov cx,6 ;; o
    rep stosw

    add di, 2 ;space
    mov cx,2 ;; r
    rep stosw
    add di, 4 ;space
    mov cx, 2
    rep stosw

    add di, 2 ;space
    mov cx,6;; e
    rep stosw

    push word[somedelay]
    call func
    ;--------18-----------
    mov di, 160*18 + 46 ; point di to top left column
    mov cx, 34
    rep stosw
    ;--------19-----------
    mov di, 160*19 + 46 ; point di to top left column
    mov cx, 34
    rep stosw
    push es
    push di
    push ds
    pop es
    xor al, al
    mov di, startmessage
    mov cx, 0xFFFF
    repne scasb
    mov ax, 0xFFFF
    sub ax, cx
    xchg ax, cx
    dec cx
    pop di
    pop es


    mov ax, 0xC720
    mov di, 160*19 + 60
    mov si, startmessage
    l11:
    lodsb
    stosw
    loop l11

    ;--------20------------
    mov di, 160*20 + 46 ; point di to top left column
    mov ax, 0x4720
    mov cx, 34
    rep stosw



    pop cx
    pop di
    pop ax
    pop es
    ret
endgame:
    push es
    push ax
    push di
    push cx
    mov ax, 0xb800
    mov es, ax ; point es to video base
    mov di, 0 ; point di to top left column
    nextl2:
    mov word [es:di], 0xff20 ; clear next char on screen
    add di, 2 ; move to next screen location
    cmp di, 4000 ; has the whole screen cleared
    jne nextl2 ; if no clear next position


    ;-------- 1 --------
    mov ax, 0xb800
    mov es, ax ; point es to video base
    mov ax, 0x4020
    mov di, 160*2 + 46 ; point di to top left column
    mov cx,6 ;;g
    rep stosw

    add di, 2 ;space
    mov cx,8 ;; a
    rep stosw


    add di, 2 ;space
    mov cx,2 ;m
    rep stosw
    add di, 8 ;space
    mov cx, 2
    rep stosw

    add di, 2 ;space
    mov cx,6 ;; e
    rep stosw

    ;-------- 2 --------
    mov di, 160*3 + 46 ; point di to top left column
    mov cx,2 ;;g
    rep stosw

    add di, 10 ;space
    mov cx,2 ;; a
    rep stosw
    add di, 8 ;space
    mov cx,2 ;; a
    rep stosw


    add di, 2 ;space
    mov cx,3 ;m
    rep stosw
    add di, 4 ;space
    mov cx,3  
    rep stosw

    add di, 2 ;space
    mov cx,2 ;; e
    rep stosw

    ;-------- 3 --------
    mov di, 160*4 + 46 ; point di to top left column
    mov cx,2 ;;g
    rep stosw

    add di, 10 ;space
    mov cx,8 ;; a
    rep stosw


    add di, 2 ;space
    mov cx,2 ;m
    rep stosw
    add di,2
    mov cx,2 ;m
    rep stosw
    add di,2
    mov cx,2 ;m
    rep stosw

    add di, 2 ;space
    mov cx,6 ;; e
    rep stosw

    ;-------- 4 --------
    mov di, 160*5 + 46 ; point di to top left column
    mov cx,2 ;;g
    rep stosw
    add di,4
    mov cx,2 ;;g
    rep stosw

    add di, 2 ;space
    mov cx,2 ;; a
    rep stosw
    add di, 8 ;space
    mov cx,2 ;; a
    rep stosw


    add di, 2 ;space
    mov cx,2 ;m
    rep stosw
    add di, 8 ;space
    mov cx,2  
    rep stosw

    add di, 2 ;space
    mov cx,2 ;; e
    rep stosw

    ;---------5--------------
    mov di, 160*6 + 46 ; point di to top left column
    mov cx,6 ;;g
    rep stosw

    add di, 2 ;space
    mov cx,2 ;; a
    rep stosw
    add di,8
    mov cx,2 ;; a
    rep stosw

    add di, 2 ;space
    mov cx,2 ;m
    rep stosw
    add di, 8 ;space
    mov cx, 2
    rep stosw

    add di, 2 ;space
    mov cx,6 ;; e
    rep stosw
    push word[somedelay]
    call func
    ;---------6----------------
    mov di, 160*8 + 46 ; point di to top left column
    mov cx,6 ;;o
    rep stosw

    add di, 2 ;space
    mov cx,2 ;; v
    rep stosw
    add di,8
    mov cx,2 ;;
    rep stosw

    add di, 2 ;space
    mov cx,8 ;e
    rep stosw

    add di, 2 ;space
    mov cx,6 ;; r
    rep stosw

    ;---------7----------------
    mov di, 160*9 + 46 ; point di to top left column
    mov cx,2 ;o
    rep stosw
    add di,4
    mov cx,2
    rep stosw

    add di, 2 ;space
    mov cx,2 ;; v
    rep stosw
    add di,8
    mov cx,2 ;;
    rep stosw

    add di, 2 ;space
    mov cx,2 ;e
    rep stosw

    add di, 14 ;space
    mov cx,2 ;; r
    rep stosw
    add di,4
    mov cx,2 ;; r
    rep stosw

    ;---------8----------------
    mov di, 160*10 + 46 ; point di to top left column
    mov cx,2 ;o
    rep stosw
    add di,4
    mov cx,2
    rep stosw

    add di, 4 ;space
    mov cx,2 ;; v
    rep stosw
    add di,4
    mov cx,2 ;;
    rep stosw

    add di, 4 ;space
    mov cx,8 ;e
    rep stosw

    add di, 2 ;space
    mov cx,4 ;; r
    rep stosw

    ;---------9----------------
    mov di, 160*11 + 46 ; point di to top left column
    mov cx,2 ;o
    rep stosw
    add di,4
    mov cx,2
    rep stosw

    add di, 4 ;space
    mov cx,2 ;; v
    rep stosw
    add di,4
    mov cx,2 ;;
    rep stosw

    add di, 4 ;space
    mov cx,2 ;e
    rep stosw

    add di, 14 ;space
    mov cx,2 ;; r
    rep stosw
    add di,4
    mov cx,2 ;; r
    rep stosw



    ;---------11----------------
    mov di, 160*12 + 46 ; point di to top left column
    mov cx,6 ;o
    rep stosw


    add di, 8 ;space
    mov cx,2 ;; v
    rep stosw

    add di, 8 ;space
    mov cx,8 ;e
    rep stosw

    add di, 2 ;space
    mov cx,2 ;; r
    rep stosw
    add di, 4 ;space
    mov cx,2
    rep stosw
    push word[somedelay]
    call func
    ;--------18-----------
    mov di, 160*18 + 46 ; point di to top left column
    mov cx, 34
    rep stosw
    ;--------19-----------
    mov di, 160*19 + 46 ; point di to top left column
    mov cx, 34
    rep stosw
    push es
    push di
    push ds
    pop es
    xor al, al
    mov di, scoremessage
    mov cx, 0xFFFF
    repne scasb
    mov ax, 0xFFFF
    sub ax, cx
    xchg ax, cx
    dec cx
    pop di
    pop es


    mov ax, 0x4720
    mov di, 160*19 + 60
    mov si, scoremessage
    l12:
    lodsb
    stosw
    loop l12

    ;--------20------------
    mov di, 160*20 + 46 ; point di to top left column
    mov ax, 0x4720
    mov cx, 34
    rep stosw


    pop cx
    pop di
    pop ax
    pop es
    ret
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
printbucket:
    push es
    push ax
    push di
    push dx
    mov ax, 0xb800
    mov es, ax ; point es to video base
    
    ;;;oldddddd clearrrr right
    mov ax,160
    mov dx,0x0013
    mul dx
    add ax, word[bpos]
    sub ax,2
    mov di, ax
    mov ax, 0x7020
    mov cx,1
    rep stosw
    mov cx,1
    rep stosw
    add di,12
    mov cx,1
    rep stosw
    mov cx,1
    rep stosw
    mov ax,160
    mov dx,0x0014
    mul dx
    add ax, word[bpos]
    sub ax, 2
    mov di, ax ; point di to top left column
    mov ax, 0x7020
    mov cx,1
    rep stosw
    mov cx,1
    rep stosw
    add di,12
    mov cx,1
    rep stosw
    mov cx,1
    rep stosw
    mov ax,160
    mov dx,0x0015
    mul dx
    add ax, word[bpos]
    mov di, ax ; point di to top left column
    mov ax, 0x7020
    mov cx,2
    rep stosw
    mov ax, 0x7020
    mov cx,4
    rep stosw
    
    mov cx,2
    rep stosw
    
    ;;old clear left
    mov ax,160
    mov dx,0x0013
    mul dx
    add ax, word[bpos]
    add ax,2
    mov di, ax
    mov ax, 0x7020
    mov cx,1
    rep stosw
    mov cx,1
    rep stosw
    add di,12
    mov cx,1
    rep stosw
    mov cx,1
    rep stosw
    mov ax,160
    mov dx,0x0014
    mul dx
    add ax, word[bpos]
    add ax, 2
    mov di, ax ; point di to top left column
    mov ax, 0x7020
    mov cx,1
    rep stosw
    mov cx,1
    rep stosw
    add di,12
    mov cx,1
    rep stosw
    mov cx,1
    rep stosw
    mov ax,160
    mov dx,0x0015
    mul dx
    add ax, word[bpos]
    add ax,4
    mov di, ax ; point di to top left column
    mov ax, 0x7020
    mov cx,2
    rep stosw
    mov ax, 0x7020
    mov cx,4
    rep stosw
    
    mov cx,2
    rep stosw
    ;;;;;;;;;;;;;;;
    mov ax,160
    mov dx,0x0013
    mul dx
    add ax, word[bpos]
    mov di, ax
    mov al,'|'
    mov ah,0x74
    mov cx,1
    rep stosw
    mov cx,1
    rep stosw
    add di,12
    mov cx,1
    rep stosw
    mov cx,1
    rep stosw
    mov ax,160
    mov dx,0x0014
    mul dx
    add ax, word[bpos]
    mov di, ax ; point di to top left column
    mov al,'|'
    mov ah,0x74
    mov cx,1
    rep stosw
    mov cx,1
    rep stosw
    add di,12
    mov cx,1
    rep stosw
    mov cx,1
    rep stosw
    mov ax,160
    mov dx,0x0015
    mul dx
    add ax, word[bpos]
    add ax,2
    mov di, ax ; point di to top left column
    mov al,'\'
    mov ah,0x74
    mov cx,2
    rep stosw
    mov al,'_'
    mov ah,0x74
    mov cx,4
    rep stosw
    
    mov al,'/'
    mov cx,2
    rep stosw
    pop dx
    pop di
    pop ax
    pop es
    ret
getinput:
    in al, 0x60
    cmp al, 0x4d ;;right
    jne checknext
    cmp word[bpos], 140
    je exit
    add word[bpos],2
    jmp exit
    checknext:
    cmp al, 0x4b ;; left
    jne exit
    cmp word[bpos], 0
    je exit
    sub word[bpos],2
    exit:
    call printbucket
    mov al,0x20
    out 0x20, al
    iret
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
start:
    call clrscr
    call startgame
    mov ax,0
    int 0x16
    xor ax, ax
    mov es, ax ; point es to IVT base
    cli ; disable interrupts
    ;hooking timer interrupts
    mov ax, word[es:8*4]
    mov word[oldtimerisr],ax
    mov ax, word[es:8*4+2]
    mov word[oldtimerisr+2],ax
    mov word [es:8*4], timer; store offset at n*4
    mov [es:8*4+2], cs ; store segment at n*4+2
    ;hooking left right key interrupts
    mov ax, word[es:9*4]
    mov word[oldkbisr],ax
    mov ax, word[es:9*4+2]
    mov word[oldkbisr+2],ax
    mov word [es:9*4], getinput ; store offset at n*4
    mov [es:9*4+2], cs ; store segment at n*4+2
    sti ; enable interrupts

    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    call printsky
    call printbucket

    c:
    cmp word[sec], 0
    je exit1
    cmp byte[GameOver], 1
    je exit1
    jmp c
      exit1:
    xor ax, ax
    mov es, ax ; point es to IVT base
    cli ; disable interrupts
    ;hooking timer interrupts
    mov ax, word[oldtimerisr]
    mov word[es:8*4],ax
    mov ax, word[oldtimerisr+2]
    mov word[es:8*4+2],ax

    mov ax, word[oldkbisr]
    mov word[es:9*4],ax
    mov ax, word[oldkbisr+2]
    mov word[es:9*4+2],ax
    sti ; enable interrupts
    call endgame
    mov ax,160*19 + 60
    push ax
    push word[score]
    call printnum
    mov ax,0
    int 0x16
    mov ax,0x4c00
    int 0x21