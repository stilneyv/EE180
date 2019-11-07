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
	ori     $t0, $t0, 0x3210
	sw      $0, 0($t0)
	ori     $t1, $0, 1
	ll		$t2, 0($t0)
    # sw      $0, 0($t0)
	sc		$t1, 0($t0)
	lw		$t2, 0($t0)
    addiu   $v0, $t1, 4
    addiu   $v0, $t2, 4
	# sltiu   $t2, $t1, 1
    sw      $t1, 4($s0)         # Set the test result
    sw      $s1, 0($s0)         # Set 'done'

$done:
    j       $done
    nop

    .end boot
