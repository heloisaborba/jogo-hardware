# Batalha Naval - MIPS (MARS)
# 2 jogadores, tabuleiros 8x8, navios 4,3,2
# Códigos: 0=água, 1=navio, 2=miss, 3=hit

        .data
prompt_player:    .asciiz "\nJogador "
msg_place:        .asciiz " - coloque navio de tamanho "
msg_orient:       .asciiz " (ex: A5 H ou A5 V ou A5): "
err_invalid:      .asciiz "Entrada invalida. Tente novamente.\n"
err_overlap:      .asciiz "Posicao invalida (sobrepoe ou ultrapassa borda). Tente outra.\n"
msg_all_placed:   .asciiz "Todos os navios colocados.\n"
msg_turn:         .asciiz "\nVez do jogador "
msg_enter_shot:   .asciiz " - informe coordenada do tiro (ex A5): "
msg_miss:         .asciiz " - Errou!\n"
msg_hit:          .asciiz " - Acertou!\n"
msg_already:      .asciiz "Ja atirado nesta posicao. Tente outra coordenada.\n"
msg_winner:       .asciiz "\n*** Jogador "
msg_winner2:      .asciiz " venceu! ***\n"
ask_continue:     .asciiz "\nPressione ENTER para trocar player...\n"
newline:          .asciiz "\n"

inbuf:            .space 64

# dois tabuleiros (64 bytes cada)
board1:           .space 64
board2:           .space 64

# tamanhos dos navios
ships:            .word 4,3,2
num_ships:        .word 3

# counters de células ainda não atingidas
ships_left1:      .word 0
ships_left2:      .word 0

        .text
        .globl main

# ---------------- IO helpers ----------------
print_str:
        # a0 = addr
        li $v0,4
        syscall
        jr $ra

read_line:
        # a0 = buffer, a1 = size
        li $v0,8
        syscall
        jr $ra

print_int:
        # a0 = int
        li $v0,1
        syscall
        jr $ra

# ---------------- parse coordinate ----------------
# Usa inbuf; retorna v0=row(0..7), v1=col(0..7) ; se erro v0=-1
parse_coord:
        la $t0, inbuf
        lb $t1, 0($t0)          # primeiro char
        beqz $t1, parse_err

        # verificar coluna A-H ou a-h
        li $t2, 'A'
        li $t3, 'H'
        blt $t1, $t2, check_lower
        bgt $t1, $t3, check_lower
        subu $v1, $t1, $t2      # col = char - 'A'
        j parse_row
check_lower:
        li $t2, 'a'
        li $t3, 'h'
        blt $t1, $t2, parse_err
        bgt $t1, $t3, parse_err
        subu $v1, $t1, $t2      # col = char - 'a'

parse_row:
        # avança para o próximo token (número)
        addi $t0, $t0, 1
skip_spaces:
        lb $t1, 0($t0)
        beqz $t1, parse_err
        li $t2, ' '
        beq $t1, $t2, inc_and_skip
        li $t2, '\t'
        beq $t1, $t2, inc_and_skip
        j got_digit
inc_and_skip:
        addi $t0, $t0, 1
        j skip_spaces

got_digit:
        lb $t1, 0($t0)
        li $t2, '1'
        li $t3, '8'
        blt $t1, $t2, parse_err
        bgt $t1, $t3, parse_err
        subu $v0, $t1, $t2      # row = digit - '1'
        jr $ra

parse_err:
        li $v0, -1
        li $v1, -1
        jr $ra

# ---------------- find orientation ----------------
# usa buffer inbuf; retorna em $t0: 0 horizontal (default), 1 vertical
find_orient:
        la $t1, inbuf
        li $t0, 0
find_orient_loop:
        lb $t2, 0($t1)
        beqz $t2, find_orient_done
        li $t3, 'H'
        beq $t2, $t3, setH
        li $t3, 'h'
        beq $t2, $t3, setH
        li $t3, 'V'
        beq $t2, $t3, setV
        li $t3, 'v'
        beq $t2, $t3, setV
        addi $t1, $t1, 1
        j find_orient_loop
setH:
        li $t0, 0
        jr $ra
setV:
        li $t0, 1
        jr $ra
find_orient_done:
        jr $ra

# ---------------- calc_index row,col -> index ----------------
# entrada: a0=row, a1=col ; saída v0 = index
calc_index:
        li $t8, 8
        mul $t2, $a0, $t8
        add $v0, $t2, $a1
        jr $ra

# ---------------- init boards ----------------
init_boards:
        # zero board1
        la $t0, board1
        li $t1, 64
zero1:
        beqz $t1, done1
        sb $zero, 0($t0)
        addi $t0, $t0, 1
        addi $t1, $t1, -1
        j zero1
done1:
        # zero board2
        la $t0, board2
        li $t1, 64
zero2:
        beqz $t1, done2
        sb $zero, 0($t0)
        addi $t0, $t0, 1
        addi $t1, $t1, -1
        j zero2
done2:
        # set ships_left = 9 (4+3+2)
        li $t0, 9
        la $t1, ships_left1
        sw $t0, 0($t1)
        la $t1, ships_left2
        sw $t0, 0($t1)
        jr $ra

# ---------------- place all ships for a board ----------------
# expects: s0 = address of board (board1 or board2)
# expects: s2 = player number (1 or 2) for printing
place_all_ships:
        la $t_ships, ships
        lw $t_num, num_ships
        li $t_idx, 0
place_loop:
        beq $t_idx, $t_num, place_done
        # load ship size
        sll $t_a, $t_idx, 2
        add $t_a, $t_a, $t_ships
        lw $t_size, 0($t_a)

ask_place:
        # print "Jogador "
        la $a0, prompt_player
        jal print_str
        move $a0, $s2
        jal print_int

        la $a0, msg_place
        jal print_str
        move $a0, $t_size
        jal print_int
        la $a0, msg_orient
        jal print_str

        # read line
        la $a0, inbuf
        li $a1, 64
        jal read_line

        # parse coordinate
        jal parse_coord
        bltz $v0, bad_input_place
        move $t_row, $v0
        move $t_col, $v1

        # find orientation
        jal find_orient
        move $t_orient, $t0    # 0 horiz, 1 vert

        # bounds check: if horiz, col + size <=8 ; if vert, row + size <=8
        beqz $t_orient, check_horiz
        # vertical
        add $t_tmp, $t_row, $t_size
        li $t_const, 8
        bgt $t_tmp, $t_const, bad_input_place
        j check_overlap
check_horiz:
        add $t_tmp, $t_col, $t_size
        li $t_const, 8
        bgt $t_tmp, $t_const, bad_input_place

check_overlap:
        li $t_off, 0
overlap_loop:
        beq $t_off, $t_size, overlap_ok
        beqz $t_orient, horiz_case
        # vertical: row+off, col
        add $t_r2, $t_row, $t_off
        move $t_c2, $t_col
        j calc_idx_place
horiz_case:
        move $t_r2, $t_row
        add $t_c2, $t_col, $t_off

calc_idx_place:
        move $a0, $t_r2
        move $a1, $t_c2
        jal calc_index
        move $t_index, $v0
        # address = s0 + index
        move $t_addr, $s0
        add $t_addr, $t_addr, $t_index
        lb $t_val, 0($t_addr)
        bnez $t_val, overlap_bad
        addi $t_off, $t_off, 1
        j overlap_loop

overlap_bad:
        la $a0, err_overlap
        jal print_str
        j ask_place

overlap_ok:
        # write ship cells (store 1)
        li $t_off, 0
write_loop:
        beq $t_off, $t_size, place_next
        beqz $t_orient, horiz_write
        add $t_r2, $t_row, $t_off
        move $t_c2, $t_col
        j calc_idx_write
horiz_write:
        move $t_r2, $t_row
        add $t_c2, $t_col, $t_off

calc_idx_write:
        move $a0, $t_r2
        move $a1, $t_c2
        jal calc_index
        move $t_index, $v0
        move $t_addr, $s0
        add $t_addr, $t_addr, $t_index
        li $t_one, 1
        sb $t_one, 0($t_addr)
        addi $t_off, $t_off, 1
        j write_loop

place_next:
        addi $t_idx, $t_idx, 1
        j place_loop

bad_input_place:
        la $a0, err_invalid
        jal print_str
        j ask_place

place_done:
        la $a0, msg_all_placed
        jal print_str
        jr $ra

# ---------------- small clear screen (newlines) ----------------
clear_screen:
        li $t0,0
clear_loop:
        beq $t0,12, clear_done
        la $a0, newline
        jal print_str
        addi $t0, $t0, 1
        j clear_loop
clear_done:
        jr $ra

# ---------------- game loop ----------------
# s4 = current player number (1 or 2)
# when s4==1: s0=board1, s3=board2, s5=&ships_left2
# when s4==2: s0=board2, s3=board1, s5=&ships_left1
game_loop:
        li $s4, 1
game_loop_top:
        beq $s4, 1, setup_p1
        # player 2
        la $s0, board2
        la $s3, board1
        la $s5, ships_left1
        j turn_start
setup_p1:
        la $s0, board1
        la $s3, board2
        la $s5, ships_left2

turn_start:
        # print "Vez do jogador "
        la $a0, msg_turn
        jal print_str
        move $a0, $s4
        jal print_int

ask_shot:
        la $a0, msg_enter_shot
        jal print_str
        la $a0, inbuf
        li $a1, 64
        jal read_line

        # parse coord
        jal parse_coord
        bltz $v0, shot_bad
        move $t_row, $v0
        move $t_col, $v1

        # calc index
        move $a0, $t_row
        move $a1, $t_col
        jal calc_index
        move $t_index, $v0

        # address on opponent board (s3)
        move $t_addr, $s3
        add $t_addr, $t_addr, $t_index
        lb $t_cell, 0($t_addr)

        # if already shot (2 or 3)
        li $t2, 2
        beq $t_cell, $t2, already_shot
        li $t2, 3
        beq $t_cell, $t2, already_shot

        # if hit (1)
        li $t_one, 1
        beq $t_cell, $t_one, do_hit

        # miss
        li $t_miss, 2
        sb $t_miss, 0($t_addr)
        la $a0, msg_miss
        jal print_str
        j after_shot

do_hit:
        li $t_hit, 3
        sb $t_hit, 0($t_addr)
        la $a0, msg_hit
        jal print_str
        # decrement ships_left
        lw $t_tmp, 0($s5)
        addi $t_tmp, $t_tmp, -1
        sw $t_tmp, 0($s5)
        beqz $t_tmp, declare_winner
        j after_shot

after_shot:
        # press enter and switch players
        la $a0, ask_continue
        jal print_str
        la $a0, inbuf
        li $a1, 8
        jal read_line

        # switch player
        beq $s4, 1, set_p2
        li $s4, 1
        j game_loop_top
set_p2:
        li $s4, 2
        j game_loop_top

already_shot:
        la $a0, msg_already
        jal print_str
        j ask_shot

shot_bad:
        la $a0, err_invalid
        jal print_str
        j ask_shot

declare_winner:
        la $a0, msg_winner
        jal print_str
        move $a0, $s4
        jal print_int
        la $a0, msg_winner2
        jal print_str
        li $v0,10
        syscall

# ---------------- main ----------------
main:
        # init boards and counters
        jal init_boards

        # player 1 placement
        li $s2, 1
        la $s0, board1
        jal place_all_ships

        # clear screen and wait
        jal clear_screen
        la $a0, ask_continue
        jal print_str
        la $a0, inbuf
        li $a1, 8
        jal read_line

        # player 2 placement
        li $s2, 2
        la $s0, board2
        jal place_all_ships

        # start game loop
        jal game_loop

        # exit (redundant)
        li $v0,10
        syscall
