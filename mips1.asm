# Batalha Naval - MIPS (MARS) - Versão Final Corrigida v2
# 2 jogadores, tabuleiros 8x8, navios 4,3,2
# Correção: Erro de Runtime Address 0x0 resolvido (Conflito de $s5).

# --- BLOCO DE DEFINIÇÕES (.eqv) ---
.eqv $t_idx    $s1  # Índice do navio atual
.eqv $t_ships  $s3  # Endereço do array 'ships'
.eqv $t_size   $s4  # Tamanho do navio atual
.eqv $t_row    $s5  # Linha (Usa $s5)
.eqv $t_col    $s6  # Coluna
.eqv $t_orient $s7  # Orientação

# --- REGISTRADORES TEMPORÁRIOS ---
.eqv $t_tmp    $t4  
.eqv $t_addr   $t4  
.eqv $t_a      $t4  
.eqv $t_val    $t5  
.eqv $t_cell   $t5  
.eqv $t_one    $t5  
.eqv $t_const  $t5  
.eqv $t_off    $t6  
.eqv $t_r2     $t7  
.eqv $t_c2     $t8  
.eqv $t_index  $t9  

        .data
# --- Strings ---
prompt_player:    .asciiz "\nJogador "
msg_place:        .asciiz " - coloque navio de tamanho "
msg_orient:       .asciiz " (ex: A5 H ou A5 V ou A5): "
err_invalid:      .asciiz "Entrada invalida. Tente novamente.\n"
err_overlap:      .asciiz "Posicao invalida (sobrepoe ou ultrapassa borda). Tente outra.\n"
msg_all_placed:   .asciiz "Todos os navios colocados.\n"
msg_turn:         .asciiz "\n--------------------------------\nVez do jogador "
msg_enter_shot:   .asciiz " - informe coordenada do tiro (ex A5): "
msg_miss:         .asciiz " -> Errou! (Agua)\n"
msg_hit:          .asciiz " -> ACERTOU! (Fogo!)\n"
msg_already:      .asciiz "Ja atirado nesta posicao. Tente outra coordenada.\n"
msg_winner:       .asciiz "\n*** Jogador "
msg_winner2:      .asciiz " venceu! ***\n"
ask_continue:     .asciiz "\nPressione ENTER para continuar...\n"
newline:          .asciiz "\n"

# --- Strings VISUAIS ---
str_header:       .asciiz "\n   1 2 3 4 5 6 7 8\n"
str_line_prefix:  .asciiz " "
sym_water:        .asciiz ". "
sym_miss:         .asciiz "o "
sym_hit:          .asciiz "X "

inbuf:            .space 64
board1:           .space 64
board2:           .space 64
ships:            .word 4,3,2
num_ships:        .word 3
ships_left1:      .word 0
ships_left2:      .word 0

        .text
        .globl main
        j main

# ---------------- IO helpers ----------------
print_str:
        li $v0,4
        syscall
        jr $ra

read_line:
        li $v0,8
        syscall
        jr $ra

print_int:
        li $v0,1
        syscall
        jr $ra

# ---------------- PRINT BOARD ----------------
print_board_masked:
        move $t0, $a0        
        
        la $a0, str_header
        li $v0, 4
        syscall

        li $t1, 0            # Linha (0-7)

pb_row_loop:
        li $t2, 8
        beq $t1, $t2, pb_done

        # Imprime Letra
        li $a0, 'A'
        add $a0, $a0, $t1
        li $v0, 11
        syscall
        
        la $a0, str_line_prefix
        li $v0, 4
        syscall

        li $t3, 0            # Coluna (0-7)

pb_col_loop:
        li $t2, 8
        beq $t3, $t2, pb_next_row

        sll $t4, $t1, 3      # row * 8
        add $t4, $t4, $t3    # + col
        add $t4, $t4, $t0    # + Base
        
        lb $t5, 0($t4)       

        li $t6, 2
        beq $t5, $t6, print_miss
        li $t6, 3
        beq $t5, $t6, print_hit
        j print_water        # Esconde navios (1 vira água)

print_water:
        la $a0, sym_water
        j do_print_sym
print_miss:
        la $a0, sym_miss
        j do_print_sym
print_hit:
        la $a0, sym_hit
        j do_print_sym

do_print_sym:
        li $v0, 4
        syscall
        addi $t3, $t3, 1     
        j pb_col_loop

pb_next_row:
        la $a0, newline
        li $v0, 4
        syscall
        addi $t1, $t1, 1     
        j pb_row_loop

pb_done:
        jr $ra

# ---------------- parse coordinate ----------------
parse_coord:
        la $t0, inbuf
        lb $t1, 0($t0)
        beqz $t1, parse_err
        li $t2, 'A'
        li $t3, 'H'
        blt $t1, $t2, check_lower
        bgt $t1, $t3, check_lower
        subu $v1, $t1, $t2   # v1 = LINHA
        j parse_row
check_lower:
        li $t2, 'a'
        li $t3, 'h'
        blt $t1, $t2, parse_err
        bgt $t1, $t3, parse_err
        subu $v1, $t1, $t2   # v1 = LINHA
parse_row:
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
        subu $v0, $t1, $t2   # v0 = COLUNA
        jr $ra
parse_err:
        li $v0, -1
        li $v1, -1
        jr $ra

# ---------------- find orientation ----------------
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

# ---------------- calc_index ----------------
calc_index:
        li $t0, 8
        mul $t2, $a0, $t0    # Row * 8
        add $v0, $t2, $a1    # + Col
        jr $ra

# ---------------- init boards ----------------
init_boards:
        la $t0, board1
        li $t1, 64
zero1:
        beqz $t1, done1
        sb $zero, 0($t0)
        addi $t0, $t0, 1
        addi $t1, $t1, -1
        j zero1
done1:
        la $t0, board2
        li $t1, 64
zero2:
        beqz $t1, done2
        sb $zero, 0($t0)
        addi $t0, $t0, 1
        addi $t1, $t1, -1
        j zero2
done2:
        li $t0, 9
        la $t1, ships_left1
        sw $t0, 0($t1)
        la $t1, ships_left2
        sw $t0, 0($t1)
        jr $ra

# ---------------- place all ships ----------------
place_all_ships:
        addi $sp, $sp, -4
        sw $ra, 0($sp)

        la $t_ships, ships
        li $t_idx, 0
place_loop:
        lw $t_tmp, num_ships
        beq $t_idx, $t_tmp, place_done

        sll $t_a, $t_idx, 2
        add $t_a, $t_a, $t_ships
        lw $t_size, 0($t_a)

ask_place:
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

        la $a0, inbuf
        li $a1, 64
        jal read_line

        jal parse_coord
        bltz $v0, bad_input_place
        
        move $t_row, $v1     # v1 é a LINHA
        move $t_col, $v0     # v0 é a COLUNA

        jal find_orient
        move $t_orient, $t0

        beqz $t_orient, check_horiz
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
        lw $ra, 0($sp)
        addi $sp, $sp, 4
        jr $ra

# ---------------- clear screen ----------------
clear_screen:
        addi $sp, $sp, -4
        sw $ra, 0($sp)
        
        li $t0,0
clear_loop:
        beq $t0,20, clear_done 
        la $a0, newline
        jal print_str
        addi $t0, $t0, 1
        j clear_loop
clear_done:
        lw $ra, 0($sp)
        addi $sp, $sp, 4
        jr $ra

# ---------------- game loop ----------------
game_loop:
        li $s4, 1
game_loop_top:
        beq $s4, 1, setup_p1
        la $s0, board2
        la $s3, board1
        la $s2, ships_left1   # CORREÇÃO: Usar $s2 em vez de $s5
        j turn_start
setup_p1:
        la $s0, board1
        la $s3, board2
        la $s2, ships_left2   # CORREÇÃO: Usar $s2 em vez de $s5

turn_start:
        la $a0, msg_turn
        jal print_str
        move $a0, $s4
        jal print_int
        
        move $a0, $s3        
        jal print_board_masked

ask_shot:
        la $a0, msg_enter_shot
        jal print_str
        la $a0, inbuf
        li $a1, 64
        jal read_line

        jal parse_coord
        bltz $v0, shot_bad
        
        move $t_row, $v1    # Linha ($s5 - sobrescrevia o ponteiro antes)
        move $t_col, $v0    # Coluna

        move $a0, $t_row
        move $a1, $t_col
        jal calc_index
        move $t_index, $v0

        move $t_addr, $s3
        add $t_addr, $t_addr, $t_index
        lb $t_cell, 0($t_addr)

        li $t2, 2
        beq $t_cell, $t2, already_shot
        li $t2, 3
        beq $t_cell, $t2, already_shot

        li $t_one, 1
        beq $t_cell, $t_one, do_hit

        # Miss
        li $t_cell, 2          
        sb $t_cell, 0($t_addr) 
        la $a0, msg_miss
        jal print_str
        j after_shot

do_hit:
        # Hit
        li $t_cell, 3          
        sb $t_cell, 0($t_addr)
        la $a0, msg_hit
        jal print_str
        
        # CORREÇÃO: Usar $s2 para acessar ships_left
        lw $t_tmp, 0($s2)
        addi $t_tmp, $t_tmp, -1
        sw $t_tmp, 0($s2)
        beqz $t_tmp, declare_winner
        j after_shot

after_shot:
        move $a0, $s3
        jal print_board_masked

        la $a0, ask_continue
        jal print_str
        la $a0, inbuf
        li $a1, 8
        jal read_line

        jal clear_screen 

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
        move $a0, $s3
        jal print_board_masked
        
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
        jal init_boards

        # Player 1 setup
        li $s2, 1
        la $s0, board1
        jal place_all_ships

        jal clear_screen
        la $a0, ask_continue
        jal print_str
        la $a0, inbuf
        li $a1, 8
        jal read_line

        # Player 2 setup
        li $s2, 2
        la $s0, board2
        jal place_all_ships

        jal clear_screen 
        jal game_loop

        li $v0,10
        syscall