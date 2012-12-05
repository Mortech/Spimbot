.text

# NOTE: This is just my code for Lab9. A lot needs changing.

# The arena is 300x300
# Therefore, for areas of 100x100, circles of radius 100=touching, 142=overlapping
# tokens have a radius of 2 (but the angle algorithm isn't exact, so we need the buffer)
# Don't need to stop to pick up a token, but we will to change heading
# TIME SYSTEM: 100,000=200, 1,000=2, 500=1

#Strategy so far: Scan the map in a specific order, moving from one section to the next until we have covered the entire map.

main:                                  # ENABLE INTERRUPTS
     li     $t4, 0x8000                # timer interrupt enable bit
     or     $t4, $t4, 0x2000           # scan interrupt bit
     or     $t4, $t4, 0x1000           # bonk interrupt bit
     or     $t4, $t4, 1                # global interrupt enable
     mtc0   $t4, $12                   # set interrupt mask (Status register)
     
	#Start a scan here
#	li $t4, 150
#	sw $t4, 0xffff0050($0)
#	li $t4, 150
#	sw $t4, 0xffff0054($0)
#	li $t4, 142
#	sw $t4, 0xffff0058($0)
#	la $t4, scandata
#	sw $t4, 0xffff005c($0)

	#below should be code to move the car to the first section (currently there is nothing)
                                       # REQUEST TIMER INTERRUPT
     lw     $v0, 0xffff001c($0)        # read current time
     add    $v0, $v0, 50               # add 50 to current time
     sw     $v0, 0xffff001c($0)        # request timer interrupt in 50 cycles

     li     $a0, 10
     sw     $a0, 0xffff0010($zero)     # drive

infinite: 
     j      infinite
     nop


.kdata                # interrupt handler data (separated just for readability)
chunkIH:.space 8      # space for two registers
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

scan_interrupt: #Here I want to decode and sort my points (and call another scan)
      sw      $zero, 0xffff0010($zero) # set velocity to 0
      sw      $a1, 0xffff0064($zero)   # acknowledge interrupt

      j       interrupt_dispatch       # see if other interrupts are waiting

timer_interrupt: # Here I want to move on to the next point (or set another timer interrupt to check for more, if I have no tokens but am not done)...
     # sw      $zero, 0xffff0010($zero) # set velocity to 0
      sw      $a1, 0xffff006c($zero)   # acknowledge interrupt
	li	$k0, 10
	sw      $k0, 0xffff0010($zero)
      li      $k0, -90                 # $k0= -90
      sw      $k0, 0xffff0014($zero)   # set angle to $k0
      sw      $zero, 0xffff0018($zero) # relative angle

	
      lw      $k0, 0xffff001c($0)      # current time
      add     $k0, $k0, 100000  
      sw      $k0, 0xffff001c($0)      # request timer in 100000

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
	l.s	$f3, three($zero)	# load 5.0
	div.s 	$f3, $f2, $f3	# v^^3/3
	sub.s	$f6, $f0, $f3	# v - v^^3/3

	mul.s	$f4, $f1, $f2	# v^^5
	l.s	$f5, five($zero)	# load 3.0
	div.s 	$f5, $f4, $f5	# v^^5/5
	add.s	$f6, $f6, $f5	# value = v - v^^3/3 + v^^5/5

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
# $a0 = base_address(bool), $a1 = length, $a2 = base_address(word[])

  li   $t0, 0           # $t0 = boolIndex, initialized to 0 
  li   $t1, 0x80000000  # $t1 = mask, initialized to 1 << 31 

compact_loop:
  bge  $t0, $a1, compact_done

  lw   $t2, 0($a0)      # $t2 = bool[boolIndex]
  lw   $t3, 0($a2)      # $t3 = word[wordIndex]
  beq  $t2, $zero, compact_else_case
  or   $t3, $t3, $t1    # t3 |= mask
  j    compact_endif

compact_else_case:
  not  $t4, $t1         # can re-use $t2 instead of using $t4
  and  $t3, $t3, $t4    # t3 &= ~mask

compact_endif:
  sw   $t3, 0($a2)      # word[wordIndex] = t3
  srl  $t1, $t1, 1      # mask = mask >> 1

  bne  $t1, $zero, compact_loop_maintainance
  addi $a2, $a2, 4      # advance word array pointer
  li   $t1, 0x80000000  # reset mask

compact_loop_maintainance:
  addi $t0, $t0, 1      # increment boolIndex
  addi $a0, $a0, 4      # advance bool array pointer
  j    compact_loop

compact_done:
  jr   $ra              # return


#Function will set bot to drive to the x, y location.
#$a0=x, $a1=y
.data
wordyo:.space 12

drive:
	sw $t0, 0xffff0020 #x-loc
	sw $t1, 0xffff0024 #y-loc
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
	sw $t0, 0xffff0018
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
	bge $t0, $a1, drive_end
	addi $t0, $t0, 3
drive_end:
	mul $t0, $t0, 500
	li $t1, 10
	sw $t1, 0xffff0010($0) # set velocity to 10
	lw $t1, 0xffff001c($0)
	add $t0, $t0, $t1
	sw $t0, 0xffff001c($0) #set timer to appropriate value
	jr $ra
