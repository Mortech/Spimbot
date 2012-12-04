.text

# NOTE: This is just my code for Lab9. A lot needs changing.

# The arena is 300x300
# tokens have a radius of 2
# Don't need to stop to pick up a token, but we will to change heading

main:                                  # ENABLE INTERRUPTS
     li     $t4, 0x8000                # timer interrupt enable bit
     or     $t4, $t4, 0x1000           # bonk interrupt bit
     or     $t4, $t4, 1                # global interrupt enable
     mtc0   $t4, $12                   # set interrupt mask (Status register)
     
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

                         # add dispatch for other interrupt types here.
	add $k0, $v0, $zero
      li      $v0, 4                   # Unhandled interrupt types

      la      $a0, unhandled_str
      syscall 
	add $v0, $k0, $zero
      j       done

bonk_interrupt:
      sw      $zero, 0xffff0010($zero) # set velocity to 0
      sw      $a1, 0xffff0060($zero)   # acknowledge interrupt

      j       interrupt_dispatch       # see if other interrupts are waiting

timer_interrupt:
      sw      $a1, 0xffff006c($zero)   # acknowledge interrupt

      li      $k0, -90                 # $k0= -90
      sw      $k0, 0xffff0014($zero)   # set angle to $k0
      sw      $zero, 0xffff0018($zero) # relative angle

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
      mfc0    $k0, $14                 # Exception Program Counter (PC)
.set noat
      move    $at, $k1                 # Restore $at
.set at 
      rfe   
      jr      $k0
      nop




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
	
