###############################################################################
# File         : movn.S
# Project      : EE180 Lab 2: MIPS
#
# Standards/Formatting:
#   MIPS gas, soft tab, 80 column
#
# Description:
#   Test the functionality of the 'movn' instruction.
#
###############################################################################

    .section .boot, "x"
    .balign 4
    .set    noreorder
    .global boot
    .ent    boot
boot:
    lui     $s0, 0x8002         # Load the base address of the status/test registers
    ori     $s1, $0, 1          # Prepare the 'done' status
    lui     $t1, 0xdeaf
    ori     $t0, $0, 0
    ori     $t1, $0, 0xbeef
    movz    $t2, $s1, $t0       # $t2 gets 1
    movz    $t1, $t0, $0        # $t1 becomes 0
    sub     $t3, $t2, $t1       # t3 = 1
    sltiu   $v0, $t2, 2
    sltiu   $v1, $t3, 2
    and     $v0, $v0, $v1
    sw      $v0, 4($s0)         # Set the test result
    sw      $s1, 0($s0)         # Set 'done'

$done:
    j       $done
    nop

    .end boot
