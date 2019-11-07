###############################################################################
# File         : xor.S
# Project      : EE180 Lab 2: MIPS
#
# Standards/Formatting:
#   MIPS gas, soft tab, 80 column
#
# Description:
#   Test the functionality of the 'xor' instruction.
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
    lui     $t0, 0xdeaf         # A = 0xdeafbeef
	lui		$t5, 0xbeef
	srl		$t5, $t5, 16
	add		$t0, $t0, $t5
	lui     $t1, 0x3141         # B = 0x31415926
    lui		$t5, 0x5926
	srl		$t5, $t5, 16
    add		$t1, $t5, $t1
	lui     $t2, 0xefee         # C = 0xefeee7c8
    lui		$t5, 0xe7c8
	srl		$t5, $t5, 16
    add		$t2, $t5, $t2
	xor     $t3, $t0, $t1       # D = xor(A,B) = 0xefeee7c9
	xor     $t4, $t2, $t3       # E = xor(C,D) = 0x1
	sw      $t4, 4($s0)         # Set the test result
    sw      $s1, 0($s0)         # Set 'done'

$done:
    j       $done
    nop

    .end boot
