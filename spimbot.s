 .data
Scan_data:	.space 163840
tokens:	.space	248 #list structure
tokens_head:	.word 0
tokens_tail:	.word 0	

#list=
#	head *
#	tail *

	#16384 bytes per and 10 parts() of it so  total 163840


scancontrol:	.word 0 #counter for scanning
tokenHunt:	.word 0	#counter for collecting
	
driveFlag:.word 0 #driving flag
tempflag:	.word 1		
	
scanlocX: .word 1, 150, 50, 50, 50, 150, 250, 250, 250 # the first one is a flag
scanlocY: .word 0, 250, 250, 150, 50, 50, 50, 150, 250	
wordyo:.space 12
	
.text

# SPIMbot MMIO
velocity	= 0xffff0010	# -10 to 10, Immediately updates SPIMbot's velocity
angle		= 0xffff0014	# -360 to 360, used when orientation_control is written to turn SPIMbot
angle_type	= 0xffff0018	# 0 relative, 1 absolute
time		= 0xffff001c	# 0 to 0xffffffff, reading gives the number of elapsed cycles, writing requests an interrupt at given time
x_loc		= 0xffff0020	# 0 to 300, gives SPIMbot's x coord
y_loc		= 0xffff0024	# 0 to 300, gives SPIMbot's y coord
print_int	= 0xffff0080	# Prints an int to the screen
print_float	= 0xffff0084	# Prints a float to the screen

one		= 0x00000001    #the number one
	
	# NOTE: This is just my code for Lab9. A lot needs changing.


	# The arena is 300x300
	# Therefore, for areas of 100x100, circles of radius 50=touching, 71=overlapping
	# tokens have a radius of 2 (but the angle algorithm isn't exact, so we need the buffer)
	# Don't need to stop to pick up a token, but we will to change heading
	# TIME SYSTEM: 100,000=200, 1,000=2, 500=1 at a speed of 10


	#Strategy so far: Scan the map in a specific order, moving from one section to the next until we have covered the entire map.

main:                                  # ENABLE INTERRUPTS
     li     $t4, 0x8000                # timer interrupt enable bit
     or     $t4, $t4, 0x2000           # scan interrupt bit
     or     $t4, $t4, 0x1000           # bonk interrupt bit
     or     $t4, $t4, 1                # global interrupt enable
     mtc0   $t4, $12                   # set interrupt mask (Status register)
	

	     
	#Start a scan here
	la $t0, tokens
	sw $0, 0($t0)
	sw $t0, 4($t0)
	li $t4, 150
	sw $t4, 0xffff0050($0)
	li $t4, 150
	sw $t4, 0xffff0054($0)
	li $t4, 50
	sw $t4, 0xffff0058($0)
	la $t4, Scan_data
	sw $t4, 0xffff005c($0)

	#below is code to move the car to the first section

	li     $a0, 150
	li	$a1, 150
	la 	$ra, infinite
	la 	$t0, drive
	li	$t9, 1
	jr 	$t0

fixHead:
	la 	$t0, tokens
	sw	$t0, tokens_head($0)


	lw	$a0, tokens_head($0) 
	sw 	$v0, 0xffff0080($0) ##
	sw 	$v1, 0xffff0080($0) ##prints to screen
	sw	$v0, 0($a0)
	sw	$v1, 4($a0)
	sw	$0, 8($a0) #setnext null
	j	backTotokens
	
gettoken:
	
	sw 	$t9 tempflag($0)

backtotokens:	

	#scan the first set

	lw 	$t0, Scan_data($0)
	sw	 $t0, 0xffff0080($0) ##
	beq	 $t0, $0, infinite ##leave if no tokens
	jal 	sort_list

	la	$a0, Scan_data
	jal	compact

	#fix the list if head is not set
	
	lw 	$a0, tokens_head($0)
	beq	$a0, $0, fixHead
	
	la	$a0, tokens_head 
	add	$a0, $a0, 16 
	sw 	$v0, 0xffff0080($0) ##
	sw 	$v1, 0xffff0080($0) ##prints to screen
	sw	$v0, 0($a0)
	sw	$v1, 4($a0)
	sw	$a0, tokens_head($0)  #save to head
	sw	$0, 8($a0) #setnext null
	sw	$0, -8($a0) #set prve next #todo set one

	
infinite:
	lw $t8,  tempflag($0)
	beq $t8, $0, gettoken 
	
 j      infinite	


   
     nop


.kdata                # interrupt handler data (separated just for readability)
chunkIH:.space 40      # space for two registers -- Don't need the others anymore
scandata:.space 16384 # space for the scanner to write into
non_intrpt_str:   .asciiz "Non-interrupt exception\n"
unhandled_str:    .asciiz "Unhandled interrupt type\n"


.ktext 0x80000180
interrupt_handler:
.set noat
      move      $k1, $at               # Save $at                               
.set at
      la      $k0, chunkIH                
            sw      $a0, 0($k0)              # Get some free registers                  
      sw      $a1, 4($k0)              # by storing them to a global variable     
      sw      $a2, 8($k0)
      sw      $t0, 12($k0)
      sw      $t1, 16($k0)
      sw      $t2, 20($k0)
      sw      $t3, 24($k0)
      sw      $t4, 28($k0)
      sw      $v0, 32($k0)
      sw      $ra, 36($k0)
      mfc0    $k0, $13                 # Get Cause register                       
      srl     $a0, $k0, 2                
      and     $a0, $a0, 0xf            # ExcCode field                            
      bne     $a0, 0, non_intrpt         

interrupt_dispatch:                    # Interrupt:                             
      mfc0    $k0, $13                 # Get Cause register, again                 
      beq     $k0, $zero, done         # handled all outstanding interrupts     

      and     $a0, $k0, 0x1000         # is there a bonk interrupt?                
      bne     $a0, 0, bonk_interrupt   

      and     $a0, $k0, 0x8000         # is there a timer interrupt?
      bne     $a0, 0, timer_interrupt

	and     $a0, $k0, 0x2000         # is there a scan interrupt?
      bne     $a0, 0, scan_interrupt

                         # add dispatch for other interrupt types here.
	add $k0, $v0, $zero
      li      $v0, 4                   # Unhandled interrupt types

      la      $a0, unhandled_str
      syscall 
	add $v0, $k0, $zero
      j       done

bonk_interrupt: #bonk shouldn't ever happen, do not need to worry about it...
      sw      $zero, 0xffff0010($zero) # set velocity to 0
      sw      $a1, 0xffff0060($zero)   # acknowledge interrupt

      j       interrupt_dispatch       # see if other interrupts are waiting

scan_interrupt: #Here I want to call a fresh scan and save my first for prossesing
     # sw      $zero, 0xffff0010($zero) # set velocity to 
        sw      $a1, 0xffff0064($zero)   # acknowledge interrupt
        lw  	$a2, scancontrol($0) #a2 is the scan number
        li      $a0 8 #the 8th time will stor the 9th value
        beq 	$a0, $a2, lastTime10
        add 	$a2, $a2, 1 
        sw 	$a2, scancontrol($0)
	mul	$a2, $a2 4
	lw 	$a1, scanlocX($a2)
        sw 	$a1, 0xffff0050($0)
        lw	$a1, scanlocY($a2)
        sw 	$a1, 0xffff0054($0)
        li 	$a1, 50
        sw 	$a1, 0xffff0058($0)
        la 	$a1, Scan_data
	mul	$a2, $a2, 4096 #(calulate the offset 4098 times 4 is16384)
	add	$a1, $a1, $a2  #add the offset
        sw 	$a1, 0xffff005c($0)
	sw	$0, tempflag($0)
        j       interrupt_dispatch       # see if other interrupts are waiting
lastTime10:
	lw	$a1, scanlocX($0)
	beq	$a1, $0, interrupt_dispatch
	sw	$0, scanlocX($0)
	 li 	$a1, 150
        sw 	$a1, 0xffff0050($0)
        li 	$a1, 150
        sw 	$a1, 0xffff0054($0)
        li 	$a1, 300
        sw 	$a1, 0xffff0058($0)
	la 	$a1, Scan_data
	add	$a1, 147456         #9 times 16384 
        sw 	$a1, 0xffff005c($0)
	 j       interrupt_dispatch       # see if other interrupts are waiting

timer_interrupt: # Here I want to move on to the next point (or set another timer interrupt to check for more, if I have no tokens but am not done)...
      sw      $zero, 0xffff0010($zero) # set velocity to 0
      sw      $a1, 0xffff006c($zero)   # acknowledge interrupt

	lw $a0, tokens_head($0)
	beq $a0, $0, after
	
	la $t1, driveFlag
	lw $t0, driveFlag($0)
	bgt $t0, 1, after
	bgt $t0, $0, again

      lw      $k0, 0xffff001c($0)      # current time
      add     $k0, $k0, 10000  
      sw      $k0, 0xffff001c($0)      # request timer in 10000
start:
	addi $t0, $0, 1
	sw $t0, 0($t1)
	lw $a1, 4($a0)
	lw $a0, 0($a0)
	sw $t1, 0xffff0080($0) ##
	sw $a0, 0xffff0080($0) ##
	sw $a1, 0xffff0080($0) ##
	sw $t1, 0xffff0080($0) ##
	la 	$ra, interrupt_dispatch
	la 	$t0, drive 
	jr 	$t0
	
again:
	addi $t0, $t0, 1
	sw $t0, 0($t1)
	lw $a1, 4($a0)
	lw $t1, 8($a0)
	lw $t0, tokens_head($0)
	sw $t1, 0($t0)
	lw $a0, 0($a0)
	la 	$ra, interrupt_dispatch
	li $t1, 1
	sw $t1, 0xffff0080($0) ##
	sw $a0, 0xffff0080($0) ##
	sw $a1, 0xffff0080($0) ##
	sw $t1, 0xffff0080($0) ##
	la 	$t0, drive 
	jr 	$t0

after:
	bne $a0, $0, start
      lw      $k0, 0xffff001c($0)      # current time
      add     $k0, $k0, 10000  
      sw      $k0, 0xffff001c($0)      # request timer in 10000
	

      j       interrupt_dispatch       # see if other interrupts are waiting

non_intrpt:                            # was some non-interrupt
add $k0, $v0, $zero
      li      $v0, 4
      la      $a0, non_intrpt_str
      syscall                          # print out an error message
add $v0, $k0, $zero
      # fall through to done

done:
      la      $k0, chunkIH
      lw      $a0, 0($k0)              # Restore saved registers
      lw      $a1, 4($k0)
      lw      $a2, 8($k0)
      lw      $t0, 12($k0)
      lw      $t1, 16($k0)
      lw      $t2, 20($k0)
      lw      $t3, 24($k0)
      lw      $t4, 28($k0)
      lw      $v0, 32($k0)
      lw      $ra, 36($k0)
      mfc0    $k0, $14                 # Exception Program Counter (PC)
.set noat
      move    $at, $k1                 # Restore $at
.set at 
      rfe   
      jr      $k0
      nop



	# $a0=xdelta, $a1=ydelta
	# CS232 Arctangent infinite series approximation example
	# see: http://www.escape.com/~paulg53/math/pi/greg/
	# computes  x - x^3/3 + x^5/5
	# -----------------------------------------------------------------------

.data
three:	.float	3.0
five:	.float	5.0
seven:.float	7.0
nine:	.float	9.0
eleven:.float	11.0
thirteen:.float	13.0
fifteen:.float	15.0
seventeen:.float	17.0
nineteen:.float	19.0
twoone:.float	21.0
twothree:.float	23.0
twofive:.float	25.0
twoseven:.float	27.0
twonine:.float	29.0
theone:.float	31.0
thethree:.float	33.0
PI:	.float	3.14159
F180:	.float  180.0
	
	.text
sb_arctan:
	li	$v0, 0		# angle = 0;

	abs	$t0, $a0	# get absolute values
	abs	$t1, $a1
	ble	$t1, $t0, no_TURN_90	  

	## if (abs(y) > abs(x)) { rotate 90 degrees }
	move	$t0, $a1	# int temp = y;
	sub	$a1, $zero, $a0	# y = -x;      
	move	$a0, $t0	# x = temp;    
	li	$v0, 90		# angle = 90;  

no_TURN_90:
	bge	$a0, $zero, pos_x 	# skip if (x >= 0)

	## if (x < 0) 
	add	$v0, $v0, 180	# angle += 180;

	pos_x:
	mtc1	$a0, $f0
	mtc1	$a1, $f1
	cvt.s.w $f0, $f0	# convert from ints to floats
	cvt.s.w $f1, $f1
	
	div.s	$f0, $f1, $f0	# float v = (float) y / (float) x;

	mul.s	$f1, $f0, $f0	# v^^2
	mul.s	$f2, $f1, $f0	# v^^3
	l.s	$f3, three($zero)	# load 3.0
	div.s 	$f3, $f2, $f3	# v^^3/3
	sub.s	$f6, $f0, $f3	# v - v^^3/3

	mul.s	$f4, $f1, $f2	# v^^5
	l.s	$f5, five($zero)	# load 5.0
	div.s 	$f5, $f4, $f5	# v^^5/5
	add.s	$f6, $f6, $f5	# value = v - v^^3/3 + v^^5/5

	mul.s	$f2, $f1, $f4	# v^^7
	l.s	$f3, seven($zero)	# load 7.0
	div.s 	$f3, $f2, $f3	# v^^7/7
	sub.s	$f6, $f6, $f3	# value - v^^7/7

	mul.s	$f2, $f1, $f2	# v^^9
	l.s	$f3, nine($zero)	# load 9.0
	div.s 	$f3, $f2, $f3	# v^^9/9
	add.s	$f6, $f6, $f3	# value + v^^9/9

	mul.s	$f2, $f1, $f2	# v^^11
	l.s	$f3, eleven($zero)	# load 11.0
	div.s 	$f3, $f2, $f3	# v^^11/11
	sub.s	$f6, $f6, $f3	# value + v^^11/11

	mul.s	$f2, $f1, $f2	# v^^13
	l.s	$f3, thirteen($zero)	# load 13.0
	div.s 	$f3, $f2, $f3	# v^^13/13
	add.s	$f6, $f6, $f3	# value + v^^13/13

	mul.s	$f2, $f1, $f2	# v^^13
	l.s	$f3, fifteen($zero)	# load 13.0
	div.s 	$f3, $f2, $f3	# v^^13/13
	sub.s	$f6, $f6, $f3	# value + v^^13/13

	mul.s	$f2, $f1, $f2	# v^^13
	l.s	$f3, seventeen($zero)	# load 13.0
	div.s 	$f3, $f2, $f3	# v^^13/13
	add.s	$f6, $f6, $f3	# value + v^^13/13

	mul.s	$f2, $f1, $f2	# v^^13
	l.s	$f3, nineteen($zero)	# load 13.0
	div.s 	$f3, $f2, $f3	# v^^13/13
	sub.s	$f6, $f6, $f3	# value + v^^13/13

	mul.s	$f2, $f1, $f2	# v^^13
	l.s	$f3, twoone($zero)	# load 13.0
	div.s 	$f3, $f2, $f3	# v^^13/13
	add.s	$f6, $f6, $f3	# value + v^^13/13

	mul.s	$f2, $f1, $f2	# v^^13
	l.s	$f3, twothree($zero)	# load 13.0
	div.s 	$f3, $f2, $f3	# v^^13/13
	sub.s	$f6, $f6, $f3	# value + v^^13/13

	mul.s	$f2, $f1, $f2	# v^^13
	l.s	$f3, twofive($zero)	# load 13.0
	div.s 	$f3, $f2, $f3	# v^^13/13
	add.s	$f6, $f6, $f3	# value + v^^13/13

	mul.s	$f2, $f1, $f2	# v^^13
	l.s	$f3, twoseven($zero)	# load 13.0
	div.s 	$f3, $f2, $f3	# v^^13/13
	sub.s	$f6, $f6, $f3	# value + v^^13/13

	mul.s	$f2, $f1, $f2	# v^^13
	l.s	$f3, twonine($zero)	# load 13.0
	div.s 	$f3, $f2, $f3	# v^^13/13
	add.s	$f6, $f6, $f3	# value + v^^13/13

	mul.s	$f2, $f1, $f2	# v^^13
	l.s	$f3, theone($zero)	# load 13.0
	div.s 	$f3, $f2, $f3	# v^^13/13
	sub.s	$f6, $f6, $f3	# value + v^^13/13

	mul.s	$f2, $f1, $f2	# v^^13
	l.s	$f3, thethree($zero)	# load 13.0
	div.s 	$f3, $f2, $f3	# v^^13/13
	add.s	$f6, $f6, $f3	# value + v^^13/13

	l.s	$f8, PI($zero)		# load PI
	div.s	$f6, $f6, $f8	# value / PI
	l.s	$f7, F180($zero)	# load 180.0
	mul.s	$f6, $f6, $f7	# 180.0 * value / PI

	cvt.w.s $f6, $f6	# convert "delta" back to integer
	mfc1	$t0, $f6
	add	$v0, $v0, $t0	# angle += delta

	jr 	$ra
	

	# copy your "insert_element_after" and "remove_element" functions here

insert_element_after:	
	# inserts the new element $a0 after $a1
	# if $a1 is 0, then we insert at the front of the list

	bne	$a1, $zero, iea_not_head # if a1 is null, we have to assign the head and tail

	lw	$t0, 0($a2) 		# $t0 = mylist->head
	sw	$t0, 8($a0)		# node->next = mylist->head;
	beqz	$t0, iea_after_head	# if ( mylist->head != NULL ) {
	sw	$a0, 4($t0)		#   mylist->head->prev = node;
		     			# }
iea_after_head:	
	sw	$a0, 0($a2)		# mylist->head = node;
	lw	$t0, 4($a2)		# $t0 = mylist->tail
	bnez	$t0, iea_done		# if ( mylist->tail == NULL ) {
	sw	$a0, 4($a2)		#   mylist->tail = node;
	iea_done:	     			# }
	jr	$ra

iea_not_head:
	lw	$t1, 8($a1)		# $t1 = prev->next
	bne	$t1, $zero, iea_not_tail# if ( prev->next == NULL ) {
	sw	$a0, 4($a2)		#   mylist->tail = node;
	b	iea_end			# }
iea_not_tail:				# else {
	sw	$t1, 8($a0)		#   node->next = prev->next;
	sw	$a0, 4($t1)		#   node->next->prev = node;
		     			# }

iea_end:	
	sw	$a0, 8($a1)		# store the new pointer as the next of $a1
	sw	$a1, 4($a0)		# store the old pointer as prev of $a0
	jr	$ra			# return
	# END insert_element_after

remove_element:
	# removes the element at $a0 (list is in $a1)
	# if this element is the whole list, we have to empty the list
	lw	$t0, 0($a1)  	        # t0 = mylist->head
	lw	$t1, 4($a1)  	        # t1 = mylist->tail
	bne	$t0, $t1, re_not_empty_list

re_empty_list:
	sw	$zero, 0($a1)		# zero out the head ptr
	sw	$zero, 4($a1)		# zero out the tail ptr
	j	re_done

re_not_empty_list:
	lw	$t2, 4($a0)		# t2 = node->prev
	lw	$t3, 8($a0)		# t3 = node->next
	bne	$t2, $zero, re_not_first# if (node->prev == NULL) {

	sw	$t3, 0($a1)		# mylist->head = node->next;
	sw	$zero, 4($t3)		# node->next->prev = NULL;
	j	re_done

re_not_first: 
	bne	$t3, $zero, re_not_last# if (node->next == NULL) {
	sw	$t2, 4($a1)		# mylist->tail = node->prev;
	sw	$zero, 8($t2)		# node->prev->next = NULL;
	j	re_done
re_not_last:
	sw	$t3, 8($t2)		# node->prev->next = node->next;
	sw	$t2, 4($t3)		# node->next->prev = node->prev;

re_done:
	sw	$zero, 4($a0)		# zero out $a0's prev
	sw	$zero, 8($a0)		# zero out $a0's next
	jr	$ra			# return
	# END remove_element
	
sort_list:  # $a0 = mylist
	lw	$t0, 0($a0)  	        # t0 = mylist->head, smallest
	lw	$t1, 4($a0)  	        # t1 = mylist->tail
	bne	$t0, $t1, sl_2_or_more	# if (mylist->head == mylist->tail) {
	jr	$ra  	  		#    return;

sl_2_or_more:
	sub	$sp, $sp, 12
	sw	$ra, 0($sp)		# save $ra
	sw	$a0, 4($sp)		# save my_list
	lw	$t1, 8($t0)  	        # t1 = trav = smallest->next
sl_loop:
	beq	$t1, $zero, sl_loop_done # trav != NULL
	lw	$t3, 0($t1) 		# trav->data
	lw	$t2, 0($t0) 		# smallest->data
	bge	$t3, $t2, sl_skip	# inverse of: if (trav->data < smallest->data) { 
	move	$t0, $t1		# smallest = trav;
sl_skip:
	lw	$t1, 8($t1)		# trav = trav->next
	j	sl_loop
	
sl_loop_done:
	sw	$t0, 8($sp)		# save smallest

	move	$a1, $a0		# my_list is arg2
	move 	$a0, $t0		# smallest is arg1
	jal 	remove_element		# remove_node(smallest, mylist);

	lw	$a0, 4($sp)		# restore my_list as arg1
	jal	sort_list		# sort_list(mylist);

	lw	$a0, 8($sp)		# restore smallest as arg1
	li	$a1, 0			# pass NULL as arg2
	lw	$a2, 4($sp)		# restore my_list as arg3
	jal	insert_element_after	# insert_node_after(smallest, NULL, mylist);

	lw	$ra, 0($sp)		# restore $ra
	add	$sp, $sp, 12
	jr	$ra
	# END sort_list

  
  
compact:
# $a0 = trav, $a1 = trav->value, $v0 = accumulator / x-return, $v1 = y-return
  li   $v0, 0                       # initialize accumulator
  lw   $a0, 0($a0)                  # load head to $a0
  
compact_loop_start:
  beq  $a0, $zero, compact_finish   # finish up when list is empty

  sll  $v0, $v0, 1                  # shift the accumulator left

  lw   $a1, 12($a0)                 # get the current node->value
  beq  $a1, $zero, compact_continue # don't set the bit when val == zero
  add  $v0, $v0, 1                  # set the bit otherwise
  
compact_continue:
  lw   $a0, 8($a0)                  # trav = trav->next
  j    compact_loop_start           # restart loop
  
compact_finish:
  and  $v1, $v0, 0x0000FFFF         # mask away bottom 16(y) to $v1
  srl  $v0, $v0, 16                 # shift top 16(x) to $v0
  j    $ra                          # return
  

#Function will set bot to drive to the x, y location.
#$a0=x, $a1=y
drive:
	lw $t0, 0xffff0020($0) #x-loc
	lw $t1, 0xffff0024($0) #y-loc
	sub $a0, $a0, $t0 #x-delta
	sub $a1, $a1, $t1 #y-delta
	la $t0, wordyo # Save variables I still want (also $ra)
	sw $a0, 0($t0)
	sw $a1, 4($t0)
	sw $ra, 8($t0)
	jal sb_arctan #find arctan (the angle I want)

	la $t0, wordyo
	lw $a0, 0($t0)
	lw $a1, 4($t0)
	lw $ra, 8($t0)
	sw $v0, 0xffff0014($0) # change angle
	li $t0, 1
	sw $t0, 0xffff0018($0)
	abs $a0, $a0 # find distance
	abs $a1, $a1
	add $t0, $a0, 0
	bge $a0, $a1, drive_afterif
	add $t0, $a1, 0
drive_afterif:
	mul $a0, $a0, $a0
	mul $a1, $a1, $a1
	add $a0, $a1, $a0
drive_loop:
	mul $t1, $t0, $t0
	bgt $t1, $a0, drive_end
	addi $t0, $t0, 3
	j drive_loop
drive_end:
	mul $t0, $t0, 500
	li $t1, 10
	sw $t1, 0xffff0010($0) # set velocity to 10
	lw $t1, 0xffff001c($0)
	add $t0, $t0, $t1
	sw $t0, 0xffff001c($0) #set timer to appropriate value
	jr $ra
compact_done:
