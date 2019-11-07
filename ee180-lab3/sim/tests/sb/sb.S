###############################################################################
# File         : lb.S
# Project      : EE180 Lab 2: MIPS
#
# Standards/Formatting:
#   MIPS gas, soft tab, 80 column
#
# Description:
#   Test the functionality of the 'lb' instruction.
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
    lui     $t0, 0              # Load some valid address 0x00003210 to register $t0
    addi    $t1, $0, 0xEF
    addi    $t2, $0, 0xBE
    addi    $t3, $0, 0xAD
    addi    $t4, $0, 0xDE
    lui     $t5, 0xDEAD
    ori     $t0, $t0, 0x3210
    ori     $t5, $t5, 0xBEEF
    sb      $t1, 3($t0)
    sb      $t2, 2($t0)
    sb      $t3, 1($t0)
    sb      $t4, 0($t0)
    lw      $v0, 0($t0)         # 0xDEADBEEF
    beq     $v0, $t5, $success
    sw      $0, 4($s0)         # Set the test result, fail bc doesn't branch
    # sw      $s1, 0($s0)         # Set 'done'


$done:
    sw      $s1, 0($s0)         # Set 'done'
    j       $done
    nop

$success:
    j       $done
    sw      $s1, 4($s0)         # Set the test result, success

    .end boot
