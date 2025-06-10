[org 0x0100]
jmp start


current_direction:      db 8 

game_status:            db 0
head_position_x:        db 40
head_position_y:        db 15
tail_position_x:        db 40
tail_position_y:        db 15
prev_head_position_x:   db 40
prev_head_position_y:   db 15
prev_tail_position_x:   db 40
prev_tail_position_y:   db 15
player_score:           dw 0
exit_flag:              db 0
screen_buffer:          times 2000 db ' '
movement_flag:          db 0
timer_ticks: dw 0
key_pressed: db 0
old_keyboard_int: dd 0
old_timer_int: dd 0

game_title_message: db "WELCOME TO SNAKE GAME", 0
inst1: db "Instructions to play ", 0
inst2: db "1.Use Arrow Keys", 0
inst3: db "2.Up/Down/Left/Right", 0
inst4: db "3.Eat food (*) to Grow", 0
inst5: db "4.Avoid Walls & Yourself", 0
inst6: db "5.Press ESC to Quit Any Time", 0
inst7: db "Press Any Key to Start Playing....", 0
gameover_message1: db "  GAME OVER!    ", 0
gameover_message2: db "            ", 0
gameover_message3: db "Choose Option you want to proceed..", 0
gameover_message4: db "1. PLAY AGAIN    ", 0
gameover_message5: db "2. EXIT GAME     ", 0
thank_you_message: db "Thanks for playing!", 0


food_temp_x: db 0
food_temp_y: db 0

keyboard_int:
    push ax
    push ds
    mov ax, cs
    mov ds, ax
    
    in al, 0x60       ; Read keyboard scan code
    mov [key_pressed], al
    
    mov al, 0x20      ; Send EOI to PIC
    out 0x20, al
    
    pop ds
    pop ax
    iret

timer_int:
    push ax
    push ds
    mov ax, cs
    mov ds, ax
    
    inc word [timer_ticks]
    
    mov al, 0x20      ; Send EOI to PIC
    out 0x20, al
    
    pop ds
    pop ax
    iret
	

	setup_interrupts:
    ; Save old interrupts
    xor ax, ax
    mov es, ax
    mov ax, [es:9*4]
    mov [old_keyboard_int], ax
    mov ax, [es:9*4+2]
    mov [old_keyboard_int+2], ax
    mov ax, [es:8*4]
    mov [old_timer_int], ax
    mov ax, [es:8*4+2]
    mov [old_timer_int+2], ax
    
    ; Set new keyboard interrupt
    cli
    mov word [es:9*4], keyboard_int
    mov [es:9*4+2], cs
    ; Set new timer interrupt
    mov word [es:8*4], timer_int
    mov [es:8*4+2], cs
    sti
    ret

restore_interrupts:
    xor ax, ax
    mov es, ax
    cli
    mov ax, [old_keyboard_int]
    mov [es:9*4], ax
    mov ax, [old_keyboard_int+2]
    mov [es:9*4+2], ax
    mov ax, [old_timer_int]
    mov [es:8*4], ax
    mov ax, [old_timer_int+2]
    mov [es:8*4+2], ax
    sti
    ret
start:
    call hide_cursor                ; Old: hide_cursor
    call clrscr              ; Old: clrscr
    call display_title_screen      ; Old: show_title

main_game_loop:
    call initialize_game           ;  reset
    call run_game                 ;  start_playing
    call show_game_over_screen    ;  show_game_over

    cmp byte [exit_flag], 1
    jne main_game_loop
    
    call clrscr
    call display_thank_you        ;  display_thank_you
    
    call exit_program            ;  exit_process

 



hide_cursor:
    mov ah, 02h
    mov bh, 0
    mov dh, 25
    mov dl, 0
    int 10h
    ret


clear_input_buffer:
    mov ah, 1
    int 16h
    jz .end_clear
    mov ah, 0h
    int 16h
    jmp clear_input_buffer
.end_clear:
    ret


exit_program:
    call restore_interrupts
    call clrscr
    call display_thank_you
    mov ah, 4ch
    int 21h
    ret


clear_screen_buffer:
    mov bx, 0
.clear_loop:  
    mov byte [screen_buffer + bx], ' '
    inc bx
    cmp bx, 2000
    jnz .clear_loop
    ret
    

write_to_buffer:
    mov di, screen_buffer
    mov al, 80
    mul dl
    add ax, cx
    add di, ax
    mov byte [di], bl
    ret
    

read_from_buffer:
    mov di, screen_buffer
    mov al, 80
    mul dl
    add ax, cx
    add di, ax
    mov bl, [di]
    ret
    

draw_string_to_buffer:
.string_loop:
    
    mov al, [si]
    cmp al, 0
    jz .end_draw
    mov byte [screen_buffer + di], al
    inc di
    inc si
    jmp .string_loop
.end_draw:
    ret
        

draw_game_screen:
    mov ax, 0b800h
    mov es, ax
    mov di, screen_buffer
    mov si, 0
.render_loop:
    mov bl, [di]
    mov bh, 0Ah
    cmp bl, 8
    jz .render_snake
    cmp bl, 4
    jz .render_snake
    cmp bl, 2
    jz .render_snake
    cmp bl, 1
    jz .render_snake
    cmp bl, '@'
    jz .render_border
    cmp bl, '*'
    jz .render_food
    jmp .render_pixel
    
.render_snake:
    mov bl, '$'
    mov bh, 09h
    jmp .render_pixel
    
.render_border:
    mov bh, 04h
    jmp .render_pixel
    
.render_food:
    mov bh, 0Dh
    
.render_pixel:
    mov [es:si], bx
    inc di
    add si, 2
    cmp si, 4000
    jnz .render_loop
    ret


display_current_score:
    mov si, .score_text
    mov di, 30
    call draw_string_to_buffer
    
    mov ax, [player_score]
    mov di, 45
    mov bx, 10
    
.convert_loop:
    xor dx, dx
    div bx
    add dl, '0'
    mov [screen_buffer + di], dl
    dec di
    cmp ax, 0
    jnz .convert_loop
    
    ret

.score_text:
    db "Current Score: ", 0


update_snake_direction:
    mov ah, 1
    int 16h
    jz .end_update
    
    mov ah, 0
    int 16h
    
    cmp al, 27
    je exit_program
    
    cmp ah, 48h
    je .move_up
    cmp ah, 50h
    je .move_down
    cmp ah, 4Bh
    je .move_left
    cmp ah, 4Dh
    je .move_right
    jmp .end_update

.move_up:
    cmp byte [current_direction], 4
    je .end_update
    mov byte [current_direction], 8
    jmp .end_update

.move_down:
    cmp byte [current_direction], 8
    je .end_update
    mov byte [current_direction], 4
    jmp .end_update

.move_left:
    cmp byte [current_direction], 1
    je .end_update
    mov byte [current_direction], 2
    jmp .end_update

.move_right:
    cmp byte [current_direction], 2
    je .end_update
    mov byte [current_direction], 1

.end_update:
    ret
        

move_snake_head:
    mov al, [head_position_y]
    mov byte [prev_head_position_y], al
    mov al, [head_position_x]
    mov byte [prev_head_position_x], al
    mov ah, [current_direction]
    cmp ah, 8
    jz .move_up
    cmp ah, 4
    jz .move_down
    cmp ah, 2
    jz .move_left
    cmp ah, 1
    jz .move_right
.move_up:
    dec word [head_position_y]
    jmp .end_move
.move_down:
    inc word [head_position_y]
    jmp .end_move
.move_left:
    dec word [head_position_x]
    jmp .end_move
.move_right:
    inc word [head_position_x]
.end_move:
    mov bl, [current_direction]
    mov ch, 0
    mov cl, [prev_head_position_x]
    mov dl, [prev_head_position_y]
    call write_to_buffer
    ret


check_collisions:
    mov ch, 0
    mov cl, [head_position_x]
    mov dh, 0
    mov dl, [head_position_y]
    call read_from_buffer
    cmp bl, '#'  
	je .game_over
	cmp bl, '$'   
	je .game_over
    cmp bl, '*'
    je .eat_food
    cmp bl, ' '
    je .move_only
.game_over:
    mov byte [game_status], 1 
.update_head:
    mov bl, 1
    mov ch, 0
    mov cl, [head_position_x]
    mov ch, 0
    mov dl, [head_position_y]
    call write_to_buffer
    ret
.eat_food:
    inc dword [player_score]
    call .update_head
    call make_fruit
    jmp .end_check
.move_only:
    call move_snake_tail
    call .update_head
.end_check:
    ret


move_snake_tail:
    mov al, [tail_position_y]
    mov byte [prev_tail_position_y], al
    mov al, [tail_position_x]
    mov byte [prev_tail_position_x], al
    mov ch, 0
    mov cl, [tail_position_x]
    mov dh, 0
    mov dl, [tail_position_y]
    call read_from_buffer
    cmp bl, 8
    jz .move_up
    cmp bl, 4
    jz .move_down
    cmp bl, 2
    jz .move_left
    cmp bl, 1
    jz .move_right
    jmp exit_program
.move_up:
    dec word [tail_position_y]
    jmp .end_move
.move_down:
    inc word [tail_position_y]
    jmp .end_move
.move_left:
    dec word [tail_position_x]
    jmp .end_move
.move_right:
    inc word [tail_position_x]
.end_move:
    mov bl, ' '
    mov ch, 0
    mov cl, [prev_tail_position_x]
    mov ch, 0
    mov dl, [prev_tail_position_y]
    call write_to_buffer
    ret


make_initial_fruits:
    mov cx, 10
.spawn_loop:
    push cx
    call make_fruit
    pop cx
    loop .spawn_loop
    ret


make_fruit:
    pusha
.find_position:
    rdtsc
    xor edx, edx
    mov ecx, 78
    div ecx
    inc edx
    mov [food_temp_x], dl

    rdtsc
    xor edx, edx
    mov ecx, 23
    div ecx
    inc edx
    mov [food_temp_y], dl

    movzx di, [food_temp_y]
    movzx bx, [food_temp_x]
    mov ax, 80
    mul di
    add ax, bx
    mov di, ax
    cmp byte [screen_buffer + di], ' '
    jne .find_position

    mov byte [screen_buffer + di], '*'
    popa
    ret

;  reset
initialize_game:
    mov word [player_score], 0
    mov ax, 0
    mov word [player_score], ax
    mov byte [game_status], al
    mov byte [movement_flag], al
  
    
	mov al, 8
	mov byte [current_direction], al 
	
    mov al, 40
    mov byte [head_position_x], al
    mov byte [prev_head_position_x], al
    mov byte [prev_tail_position_x], al
    mov byte [tail_position_x], al
    mov al, 15
    mov byte [head_position_y], al
    mov byte [prev_head_position_y], al
    mov byte [tail_position_y], al
    mov byte [prev_tail_position_y], al
    ret

; start_playing
run_game:
    call initialize_game
    call clear_screen_buffer
    call draw_game_border
    call make_initial_fruits
    call setup_interrupts
    
    mov word [timer_ticks], 0
    mov byte [key_pressed], 0
    
.game_loop:
    ; Check if 3 ticks have passed (controls game speed)
    cmp word [timer_ticks], 4
    jb .check_input
    
    mov word [timer_ticks], 0
    call process_input
    call move_snake_head
    call check_collisions
    call display_current_score
    call draw_game_screen
    
    mov al, [game_status]
    cmp al, 0
    jnz .end_game
    
.check_input:
    ; No need for explicit input check - handled by interrupt
    hlt              ; Wait for next interrupt
    jmp .game_loop
    
.end_game:
    call restore_interrupts
    ret

process_input:
    cmp byte [key_pressed], 0
    je .end_process
    
    mov al, [key_pressed]
    mov byte [key_pressed], 0
    
    cmp al, 0x01     ; ESC key
    je exit_program
    
    cmp al, 0x48     ; Up arrow
    je .move_up
    cmp al, 0x50     ; Down arrow
    je .move_down
    cmp al, 0x4B     ; Left arrow
    je .move_left
    cmp al, 0x4D     ; Right arrow
    je .move_right
    jmp .end_process

.move_up:
    cmp byte [current_direction], 4
    je .end_process
    mov byte [current_direction], 8
    jmp .end_process

.move_down:
    cmp byte [current_direction], 8
    je .end_process
    mov byte [current_direction], 4
    jmp .end_process

.move_left:
    cmp byte [current_direction], 1
    je .end_process
    mov byte [current_direction], 2
    jmp .end_process

.move_right:
    cmp byte [current_direction], 2
    je .end_process
    mov byte [current_direction], 1

.end_process:
    ret


clrscr: 
    push es
    push ax
    push di
    mov ax, 0xb800
    mov es, ax
    mov di, 0
.clear_loop: 
    mov word [es:di], 0x0720
    add di, 2
    cmp di, 4000
    jne .clear_loop
    pop di
    pop ax
    pop es
    ret


draw_game_border:
    mov di, 80
    mov cx, 80
	mov bl, 0Ah
.top:
    mov byte [screen_buffer + di], '@'
    inc di
    loop .top

    mov di, 1920
    mov cx, 80
.bottom:
    mov byte [screen_buffer + di], '@'
    inc di
    loop .bottom

    mov di, 80
    mov cx, 23
.sides:
    mov byte [screen_buffer + di], '@'
    mov byte [screen_buffer + di + 79], '@'
    add di, 80
    loop .sides

    mov byte [screen_buffer + 80], '@'
    mov byte [screen_buffer + 159], '@'
    mov byte [screen_buffer + 1920], '@'
    mov byte [screen_buffer + 1999], '@'
    ret


show_game_over_screen:
    call clear_screen_buffer
    call draw_game_border
    
	mov si, gameover_message1
    mov di, 800 + 32
    call draw_string_to_buffer
    
    mov si, gameover_message2
    mov di, 880 + 32
    call draw_string_to_buffer
    
    mov si, gameover_message3
    mov di, 960 + 32
    call draw_string_to_buffer
    
    mov si, gameover_message4
    mov di, 1040 + 32
    call draw_string_to_buffer
	
	mov si, gameover_message5
    mov di, 1120 + 32
    call draw_string_to_buffer
    
    call draw_game_screen
    call clear_input_buffer

.wait_choice:
    mov ah, 0
    int 16h
    cmp al, '1'
    je .restart
    cmp al, '2'
    je .exit
    jmp .wait_choice

.exit:
    mov byte [exit_flag], 1
    ret

.restart:
    mov byte [exit_flag], 0
    ret


display_title_screen:
    call clear_screen_buffer
    call draw_game_screen
    
    mov si, game_title_message
    mov di, 400 + 30
    call draw_string_to_buffer
    
    mov si, inst1
    mov di, 594
    call draw_string_to_buffer
    
    mov si, inst2
    mov di, 674
    call draw_string_to_buffer
    
    mov si, inst3
    mov di, 754
    call draw_string_to_buffer
    
    mov si, inst4
    mov di, 834
    call draw_string_to_buffer
    
    mov si, inst5
    mov di, 914
    call draw_string_to_buffer
    
    mov si, inst6
    mov di, 994
    call draw_string_to_buffer

    mov si, inst7
    mov di, 1200 + 30
    call draw_string_to_buffer
    
    call draw_game_screen
    call clear_input_buffer
    jmp .wait_keypress

.wait_keypress:
    mov ah, 0
    int 16h
    ret


display_thank_you:
    call clrscr
    mov ax, 0b800h
    mov es, ax
    mov di, (12*80 + 34)*2
    
    mov si, thank_you_message
.print_char:
    lodsb
    test al, al
    jz .done_printing
    stosb
    mov byte [es:di], 0Eh
    inc di
    jmp .print_char
.done_printing:
ret
