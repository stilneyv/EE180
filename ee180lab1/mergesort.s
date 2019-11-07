#==============================================================================
# File:         mergesort.s (PA 1)
#
# Description:  Skeleton for assembly mergesort routine. 
#
#       To complete this assignment, add the following functionality:
#
#       1. Call mergesort. (See mergesort.c)
#          Pass 3 arguments:
#
#          ARG 1: Pointer to the first element of the array
#          (referred to as "nums" in the C code)
#
#          ARG 2: Number of elements in the array
#
#          ARG 3: Temporary array storage
#                 
#          Remember to use the correct CALLING CONVENTIONS !!!
#          Pass all arguments in the conventional way!
#
#       2. Mergesort routine.
#          The routine is recursive by definition, so mergesort MUST 
#          call itself. There are also two helper functions to implement:
#          merge, and arrcpy.
#          Again, make sure that you use the correct calling conventions!
#
#==============================================================================

.data
HOW_MANY:   .asciiz "How many elements to be sorted? "
ENTER_ELEM: .asciiz "Enter next element: "
ANS:        .asciiz "The sorted list is:\n"
SPACE:      .asciiz " "
EOL:        .asciiz "\n"
TESTSTRING: .asciiz "hello\n"
MERGETEST:  .asciiz "MERGELOOP\n\n"
ARRTESTSTR: .asciiz "ArrayCPY\n\n"

.text
.globl main

#==========================================================================
main:
#==========================================================================

    #----------------------------------------------------------
    # Register Definitions
    #----------------------------------------------------------
    # $s0 - pointer to the first element of the array
    # $s1 - number of elements in the array
    # $s2 - number of bytes in the array
    #----------------------------------------------------------
    
    #---- Store the old values into stack ---------------------
    addiu   $sp, $sp, -32
    sw      $ra, 28($sp)

    #---- Prompt user for array size --------------------------
    li      $v0, 4              # print_string
    la      $a0, HOW_MANY       # "How many elements to be sorted? "
    syscall         
    li      $v0, 5              # read_int
    syscall 
    move    $s1, $v0            # save number of elements

    #---- Create dynamic array --------------------------------
    li      $v0, 9              # sbrk
    sll     $s2, $s1, 2         # number of bytes needed
    move    $a0, $s2            # set up the argument for sbrk
    syscall
    move    $s0, $v0            # the addr of allocated memory


    #---- Prompt user for array elements ----------------------
    addu    $t1, $s0, $s2       # address of end of the array
    move    $t0, $s0            # address of the current element
    j       read_loop_cond

read_loop:
    li      $v0, 4              # print_string
    la      $a0, ENTER_ELEM     # text to be displayed
    syscall
    li      $v0, 5              # read_int
    syscall
    sw      $v0, 0($t0)     
    addiu   $t0, $t0, 4

read_loop_cond:
    bne     $t0, $t1, read_loop 

    #---- Call Mergesort ---------------------------------------
    # ADD YOUR CODE HERE! 
	
	# store old values
    addiu   $sp, $sp, -32		# set stack pointerr
    sw      $ra, 28($sp)		# save ra register for restoring

    # create temp_array - num bytes = $s1
    li      $v0, 9              # sbrk
    sll		$s2, $s1, 2
	move    $a0, $s2            # set up the argument for sbrk
    syscall

    # You must use a syscall to allocate
    # temporary storage (temp_array in the C implementation)
    # then pass the three arguments in $a0, $a1, and $a2 before
    # calling mergesort
    move $a0, $s0
    move $a1, $s1
    move $a2, $v0

    # now actually call mergesort
	jal mergesort

    #---- Print sorted array -----------------------------------
    li      $v0, 4              # print_string
    la      $a0, ANS            # "The sorted list is:\n"
    syscall

    #---- For loop to print array elements ----------------------
    
    #---- Iniliazing variables ----------------------------------
    move    $t0, $s0            # address of start of the array
    addu    $t1, $s0, $s2       # address of end of the array
    j       print_loop_cond

print_loop:
    li      $v0, 1              # print_integer
    lw      $a0, 0($t0)         # array[i]
    syscall
    li      $v0, 4              # print_string
    la      $a0, SPACE          # print a space
    syscall            
    addiu   $t0, $t0, 4         # increment array pointer

print_loop_cond:
    bne     $t0, $t1, print_loop

    li      $v0, 4              # print_string
    la      $a0, EOL            # "\n"
    syscall          

    #---- Exit -------------------------------------------------
    lw      $ra, 28($sp)
    addiu   $sp, $sp, 32
    jr      $ra


# ADD YOUR CODE HERE! 

mergesort: 

	# callee setup
	addiu	$sp, $sp, -32		# allocate memory for new frame
	sw		$ra, 28($sp)		# store previous ra in stack
	
    # exit if the array length is less than 2
	slti	$t0, $a1, 2			# if (a1 < 2) set t0 == 1, else t0 = 0	
	addi	$t1, $zero, 1
	beq		$t1, $t0, return

    # handle recursion

    # get the middle of the array - store in 24($2p)
    srl		$t0, $a1, 1			# t0 = a1 / 2
	sw		$t0, 24($sp)		# store middle value for use later

	# save input args
	sw		$a0, 20($sp)		# save original input array address
	sw		$a1, 16($sp)		# save original input array len
	sw		$a2, 12($sp)		# save original temp_array address

    # setup args
    move    $a1, $t0			# set array length equal to mid

    # jump to next iteration
    jal       mergesort

    # Second recursion
	
	# load required input values from the stack
	lw      $a0, 20($sp)		# load in original input array address
	lw		$a1, 16($sp)		# load original len of array
	lw		$a2, 12($sp)		# laod original temp_array
	lw		$t0, 24($sp)		# load middle index of the array len

    # setup args for second recursion and call
    sll		$t1, $t0, 2			# t1 = mid * 4
	add		$a0, $a0, $t1		# a0 = a0 + mid *4

	sub		$a1, $a1, $t0		# n = n - mid

    jal       mergesort

    # merge both sides of the array
	lw		$a0, 20($sp)        # load in original input array address
	lw      $a1, 16($sp)        # load original len of array
	lw		$a2, 12($sp)		# load original temp_array
	lw      $a3, 24($sp)        # load middle index of the array len

    jal       merge

	# restore initial values
	lw		$ra, 28($sp)		# restore the initial return address
	addiu	$sp, $sp, 32		# return stack pointer to top
    
	jr      $ra

return:

	# restore initial values
	lw      $ra, 28($sp)        # restore the initial return address
	addiu   $sp, $sp, 32        # return stack pointer to top

	jr      $ra

merge:
	# inputs:
	# a0 = input array   a1 = n   a2 = temp array   a3 = mid

	# callee setup
	addiu   $sp, $sp, -32       # allocate memory for new frame
	sw      $ra, 28($sp)        # store previous ra in stack
	
	# store arguments
	sw		$a0, 24($sp)		# input array
	sw		$a1, 20($sp)		# number of elements in the array
	sw		$a2, 16($sp)		# address of temp array
	sw		$a3, 12($sp)		# mid value

	# initialize variables
	# t0 = tpos,   t1=lpos,   t2=rpos,    t3 = rn = n - mid,    t4 = rarr = array + mid*4
	add		$t0, $zero, $zero	# tpos = 0
	add		$t1, $zero, $zero	# lpos = 0
	add		$t2, $zero, $zero	# rpos = 0
	sub		$t3, $a1, $a3		# t3 = n - mid
	
	sll		$t5, $a3, 2			# t5 = mid * 4
	add		$t4, $a0, $t5		# t4 = array + mid*4

	# main merge while loop
	j mergeLoopCond
mergeLoop:

	# body of merge function while loop
	sll		$t5, $t1, 2		# t5 = lpos * 4
	add		$t5, $a0, $t5	# t5 = array + lpos * 4
	sll		$t6, $t2, 2		# t6 = rpos * 4
	add		$t6, $t4, $t6	# t6 = rarr + rpos * 4
	
	lw		$t5, 0($t5)		# t5 = array[lpos] loaded from memory
	lw		$t6, 0($t6)		# t6 = rarr[rpos] loaded from memory

	slt		$t7, $t5, $t6	# t5 = 1 if (t5< t6)  else t5 = 0	
	beq		$t7, $zero, innerElseCond
	# inside if statement block
	
	sll		$t5, $t0, 2		# t5 = t0 * 4 = tpos * 4
	add		$t5, $a2, $t5	# t5 = a2 + t5 = temp_array + tpos*4
	
	sll		$t6, $t1, 2		# t6 = t1 * 4 = lpos * 4
	add		$t6, $a0, $t6	# t6 = a0 + t6 = array + lpos*4

	lw		$t7, 0($t6)		# t7 = array[lpos] loaded from memory
	sw		$t7, 0($t5)		# temp_array[tpos] = t7 = array[lpos]
	
	addi    $t0, $t0, 1     # t0++ = tpos++
	addi    $t1, $t1, 1     # t1++ = lpos++

	j		mergeLoopCond
innerElseCond:
	# else statement block
	sll     $t5, $t0, 2     # t5 = t0 * 4 = tpos * 4
	add     $t5, $a2, $t5   # t5 = a2 + t5 = temp_array + tpos*4

	sll     $t6, $t2, 2     # t6 = t2 * 4 = rpos * 4
	add     $t6, $t4, $t6   # t6 = t4 + t6 = rarr + rpos*4

	lw		$t7, 0($t6)		# t7 = rarr[rpos] loaded from memory
	sw		$t7, 0($t5)		# temp_arra[tpos] = t7 = rarr[rpos]

	addi	$t0, $t0, 1		# t0++ = tpos++
	addi    $t2, $t2, 1     # t2++ = rpos++

mergeLoopCond:
	slt		$t5, $t1, $a3	# if (t1 < a3) then t5 = 1, else t5 = 0
	slt		$t6, $t2, $t3	# if (t2 < t3) then t6 = 1, else t6 = 0
	and		$t7, $t5, $t6	# t7 = t5 & t6
	bne		$t7, $zero, mergeLoop

	#------ End loop ------

	# if (lpos < mid) -> copy_array(temp_array + tpos, array + lpos, mid - lpos)
	slt     $t5, $t1, $a3   # if (t1 < a3) then t5 = 1, else t5 = 0
	beq		$t5, $zero, exitLposLTmid
	# handle the case that t1 < a3 --> call copy_array
	sll		$t7, $t0, 2		# t7 = t0 * 4 = tpos * 4
	lw		$a2, 16($sp)	# load the addr of the temp array
	add		$a0, $a2, $t7	# a0 = a2 + tpos * 4 = temp_array + tpos * 4

	sll		$t7, $t1, 2		# t7 = t1 * 4 = lpos * 4
	lw		$t9, 24($sp)	# load the address of the array from stack
	add		$a1, $t9, $t7	# a1 = t9 + lpos * 4 = array + lpos * 4
	
	sub		$a2, $a3, $t1	# a2 = mid - lpos
	
	jal		arrcpy

exitLposLTmid:
	
	# if (rpos < rn) --> copy_array(temp_array + tpos, rarr + rpos, rn - rpos)
	slt     $t6, $t2, $t3   # if (t2 < t3) then t6 = 1, else t6 = 0
	beq		$t6, $zero, exitRposLTrn
	# handle the case that t2 < rn --> call copy_array
	
	sll     $t7, $t0, 2     # t7 = t0 * 4 = tpos * 4
	lw		$t9, 16($sp)	# load address of temp_array from stack
	add     $a0, $t9, $t7   # a0 = t9 + tpos * 4 = temp_array + tpos * 4

	sll     $t7, $t2, 2     # t7 = t2 * 4 = rpos * 4
	add     $a1, $t4, $t7   # a1 = t4 + rpos * 4 = rarr + lpos * 4

	sub		$a2, $t3, $t2	# a2 = rn - rpos

	jal		arrcpy

exitRposLTrn:

	# final call to copy_array to copy temp array back to array
	lw      $a0, 24($sp)        # load in input array addr
	lw      $a2, 20($sp)        # input array len
	lw      $a1, 16($sp)        # temp array address
	lw      $a3, 12($sp)        # mid value

	jal		arrcpy
	
	# restore initial values
	lw      $ra, 28($sp)        # restore the initial return address
	addiu   $sp, $sp, 32        # return stack pointer to top

	jr      $ra               

arrcpy:
	# input params: dst: a0, src: a1, n = a2

	# don't need to update the sp, or store the ra since we don't really use it

	# copy array main for loop - using t7-t9 for vars to avoid storing them
	add		$t7, $zero, $zero	# i = 0
	j		copyTest
loop:

	# load and set memory for arrays from stack 
	lw		$t8, 0($a1)			# t8 = *a1	loaded from memory
	sw		$t8, 0($a0)			# *dst = t8 = *a1

	# now increment the pointers
	addi	$t7, $t7, 1			# i++
	addiu	$a0, $a0, 4			# dst = dst + 4
	addiu	$a1, $a1, 4			# src = src + 4

copyTest:
	slt		$t8, $t7, $a2		# t8 = 1 if t7 < a2 (i < n) else set t8 = 0
	bne		$t8, $zero, loop	# branch to content of loop

	# return
    jr      $ra
