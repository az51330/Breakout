TITLE Breakout

; breakout.asm
; A.J. Zuckerman
; ajzucker@hamilton.edu
; Spring 2021

; Creates a playable version of the 70s arcade game breakout

INCLUDE CS240.inc

.8086

FIRST_SEED = 0100110001110000b

.data

handlervector Label DWORD
handleroffset WORD 0000h
handlersegment WORD 0000h

bios_clock_int BYTE 1ch

lives BYTE 3 ; number of lives the player has left
lives_r BYTE 0 ; loc of lives on screen
lives_c BYTE 77
lost_life BYTE 0 ; t/f for loss of life to reset paddle

score_ones BYTE 9 ; ones score of the game
score_tens BYTE -1 ; tens score of the game
score_r BYTE 0 ; loc of score on screen
score_c BYTE 75
score_tc BYTE 74

tick BYTE 0 ; this is a t/f for moveball

ball_r BYTE 23 ; current row location of ball
ball_c BYTE 39 ; current col location of ball
ball_hori BYTE 1 ; ball horizontal velocity
ball_vert BYTE -1 ; ball vertical velocity
ball_char BYTE 254 ; this is the printable char for the ball
ball_color BYTE 00001111b ; this is color of the ball

paddle_char BYTE 223 ; this is the paddle character
paddle_color BYTE 00001111b ; this is the color of the paddle
paddle_locs BYTE 35, 36, 37, 38, 39, 40, 41, 42, 43, 44, 45, 46 ; these are the locations of the paddle chars

block_mid_char BYTE 219 ; this is the brick character
block_mid_color BYTE 00000100b ; this is the color of the first printed row of bricks

contact BYTE 0 ; this is a t/f for CheckCorner

win_mes BYTE 'YOU WIN!' ; message for winning
los_mes BYTE 'YOU LOSE' ; message for losing
splash_mes BYTE 'BREAKOUT' ; message for splash screen
win_r BYTE 15 ; location of print message for win/loss
win_c BYTE 36

brick_hz WORD 3615
wall_hz WORD 1811
paddle_hz WORD 630

timer BYTE 0

         ; a     b     c     d     e     f     g     a     e     c     g      nothing
notes WORD 5424, 4831, 4554, 4058, 3615, 3419, 3044, 2718, 7231, 9108, 12175, 1
intro_key BYTE 8, 2, 4, 6, 4, 2, 0, 0, 4, 8, 6, 4, 2, 2, 4, 6, 8, 4, 0, 0
intro_length BYTE 14, 7, 7, 14, 7, 7, 14, 7, 7, 14, 7, 7, 14, 7, 7, 14, 14, 14, 14, 14

win_key BYTE 22, 6, 10, 14, 12, 10, 8, 4, 8, 6, 4, 2, 2, 4, 6, 8, 4, 0, 0
win_length BYTE 7, 14, 7, 14, 7, 7, 21, 7, 14, 7, 7, 14, 7, 7, 14, 14, 14, 14, 14

loss_key BYTE 22, 4, 10, 22, 10, 10, 8, 6, 4, 16, 22, 18, 20
loss_length BYTE 7, 7, 14, 3, 7, 7, 7, 7, 7, 7, 3, 7, 7


Random16Seed WORD FIRST_SEED

.code

Random16 PROC
     ;; returns:
	   ;; ax - a 16-bit random number
.386
     pushf
	   push	edx
	   push	eax

	   cmp Random16Seed, FIRST_SEED
	   jne good
	   call Randomize
good:
     add	Random16Seed, 0FC15h
	   movzx eax, Random16Seed
	   mov edx, 02ABh
	   mul edx
	   mov edx, eax
	   shr edx, 16
	   xor eax, edx
	   and eax, 0FFFFh
	   mov edx, eax

	   pop eax
	   mov ax, dx
	   pop edx
	   popf
	   ret
.8086
Random16 ENDP

Randomize PROC
     ;; sets seed to current hundreths of seconds
	   pushf
	   push ax
	   push	bx
	   push	cx
	   push	dx

	   mov ah,2Ch
	   int 21h		; ch (hrs), cl (mins), dh (sec), dl (hsec)

	   mov bh, 0
	   mov bl, dl

	   mov dh, 0
	   mov dl, dh
	   mov ax, 100
	   mul dx
	   add bx, ax

	   mov dh, 0
	   mov dl, cl
	   mov ax, 6000
	   mul dx
	   add bx, ax

	   mov Random16Seed, bx
	   pop dx
	   pop cx
	   pop bx
	   pop ax
	   popf
	   ret
Randomize ENDP

RandRange PROC
	   ;; ax - maximum value + 1
	   ;; returns:
	   ;; ax - a value between 0 - (ax - 1)
	   pushf
	   push	bx
	   push	dx

	   mov bx, ax
	   call	Random16
	   mov dx, 0
	   div bx
	   mov ax, dx

	   pop dx
	   pop bx
	   popf
	   ret
RandRange ENDP

SetTimer PROC
     ; sets timer to a number passed in dl
     pushf
     push dx

     mov timer[0], dl

     pop dx
     popf
     ret
SetTimer ENDP

SetInterruptVector PROC
     ; al is the vector number
     ; dx is the offset of the new procedure
     pushf
     push ax
     push bx
     push ds

     mov bx, cs
     mov ds, bx
     mov ah, 25h
     int 21h

     pop ds
     pop bx
     pop ax
     popf
     ret
SetInterruptVector ENDP

SaveVector PROC
     ; saves the vector of an interrupt to DWORD
     ; vector in bx
     pushf
     push bx

     mov handlersegment[0], bx
     mov handleroffset[0], es

     pop bx
     popf
     ret
SaveVector ENDP

RestoreVector PROC
     ; restores the vector in the DWORD to its proper interrupt
     ; just like SetInterruptVector but used ES instead of CS
     pushf
     push ax
     push bx
     push dx
     push ds

     mov bx, handleroffset[0]

     mov dx, handlersegment[0]

     mov al, bios_clock_int[0]

     mov ds, bx

     mov ah, 25h
     int 21h

     pop ds
     pop dx
     pop bx
     pop ax
     popf
     ret
RestoreVector ENDP

GetInterruptVector PROC
     ; get the location of a given vector in the interrupt vector table
     ; al is interrupt vector wanted
     ; returns location in ES:BX
     pushf
     push ax

     mov ah, 35h
     int 21h

     pop ax
     popf
     ret
GetInterruptVector ENDP

RowCol2Index PROC
     ; ch row number
     ; cl col number
     ; return index in ax
     pushf
     push cx

     mov ax, 80
     mul ch ; ch * al -> ax
     mov ch, 0
     add ax, cx ; remember (r80 +c)*2
     shl ax, 1

     pop cx
     popf
     ret
RowCol2Index ENDP

ScreenChar PROC
     ; ch row number
     ; cl col number
     ; al character to print to screen
     ; ah character attributes
     push ax
     push di
     push es

     mov di, 0B800h
     mov es, di ; set es to memory mapped I/O

     push ax ; save value of ax

     call RowCol2Index ; set row col to actual location in memory

     mov di, ax ; save offset of the location wanted

     pop ax ; return ax

     mov es:[di], ax ; put ax into the mmI/o

     pop es
     pop di
     pop ax
     ret
ScreenChar ENDP

SpeakerOn PROC
     ; turns the speaker on
     pushf
     push ax

     in al, 61h
     or al, 03h
     out 61h, al

     pop ax
     popf
     ret
SpeakerOn ENDP

SpeakerOff PROC
     ; turns speaker off
     pushf
     push ax

     in al, 61h
     and al, 0FCh
     out 61h, al

     pop ax
     popf
     ret
SpeakerOff ENDP

PlayCount PROC
     ; plays the frequency of 1193180/count through the speaker
     ; dx is the count
     pushf
     push ax

     mov al, 0B6h ; special speaker wake up number
     out 43h, al
     mov al, dl
     out 42h, al
     mov al, dh
     out 42h, al

     pop ax
     popf
     ret
PlayCount ENDP

StartBall PROC
     ; puts the ball on the screen at location r: 23 c: 39
     pushf
     push ax
     push cx

     cmp ch, ball_r[0] ; check if it is time to print out the ball on start
     jne done
     cmp cl, ball_c[0]
     jne done
     mov al, ball_char[0] ; move ball char into ax
     mov ah, ball_color[0] ; this should be the attributes for an all white ball
     call ScreenChar


done:
     pop cx
     pop ax
     popf
     ret
StartBall ENDP

PrintPaddle PROC
     ; puts paddle at the bottom of the screen r: 24, c: 36, 37, 38, 39, 40, 41, 42, 43
     pushf
     push ax
     push cx
     push si

     mov ch, 24 ; paddle stays at r 24 the whole game
     mov al, paddle_char[0] ; the paddle character
     mov ah, paddle_color[0] ; this is just white with black background no blink
     mov si, 0
     jmp cond
top:
     mov cl, paddle_locs[si] ; paddle goes six rows starting at 36 originally
     call ScreenChar
     inc si
cond:
     cmp si, 9
     jl top

     pop si
     pop cx
     pop ax
     popf
     ret
PrintPaddle ENDP

ChangeColor PROC
     ; changes the color of the bricks for PrintBlocks
     pushf

     cmp ah, 00000100b ; if red go to orange
     jne red

     mov ah, 00000110b
     jmp done

red:

     cmp ah, 00000110b ; if orange go to yellow
     jne orange

     mov ah, 00001110b
     jmp done

orange:

     cmp ah, 00001110b ; if yellow go to green
     jne yellow

     mov ah, 00000010b
     jmp done

yellow:

     cmp ah, 00000010b ; if green go to blue
     jne green

     mov ah, 00001001b
     jmp done

green:

done:
     popf
     ret
ChangeColor ENDP

PrintBlocks PROC
     ; prints out the blocks at the beginning
     pushf
     push ax
     push cx

     mov al, block_mid_char[0] ; move the block char into al
     mov ah, block_mid_color[0] ; move the first color in the attributes slot
     mov ch, 3 ; set cl to the starting row of the bricks
     mov cl, 0 ; set the col to 0
     jmp cond
top:
     call ScreenChar ; print the char
     cmp cl, 79 ; if last in row go to next one
     je up
     inc cl
     jmp cond ; else don't
up:
     inc ch
     call ChangeColor ; change color on row change
     mov cl, 0
cond:
     cmp ch, 8
     jl top

     pop cx
     pop ax
     popf
     ret
PrintBlocks ENDP

PaddleSound PROC
     ; makes the sound for the paddle and sets timer to appropriate length
     pushf
     push dx

     mov dx, paddle_hz[0]
     call PlayCount

     call SpeakerOn

     mov dx, 0
     mov dl, 6
     call SetTimer

     pop dx
     popf
     ret
PaddleSound ENDP

CheckPaddle PROC
     ; checks if the paddle has been hit
     ; cl has col
     pushf
     push bx
     push si

     mov si, 0
     jmp cond
top:
     mov bl, paddle_locs[si] ; checks if the paddle is below
     cmp bl, cl
     jne nopad

     call PaddleSound

     mov ball_vert[0], -1 ; if it is then flip vert movement
     cmp si, 4 ; check if paddle should apply left or right movement
     jl left

     cmp ball_hori[0], 1 ; if right movement < 2 inc by one
     jg nopad
     inc ball_hori
     jmp nopad

left:

     cmp ball_hori[0], -1 ; if left movement > -2 dec by one
     jl nopad
     dec ball_hori

nopad:
     inc si ; if no pad keep going
cond:
     cmp si, 9
     jl top

     call PrintPaddle ; print paddle bc ball runs through it

     pop si
     pop bx
     popf
     ret
CheckPaddle ENDP

ChangeLives PROC
     ; updates the screen to show the amount of lives on it
     pushf
     push ax
     push cx

     mov al, lives[0] ; change lives on the screen by replacing the old one on the screen
     add al, 48
     mov ah, ball_color[0] ; ball color is just white
     mov cl, lives_c[0]
     mov ch, lives_r[0]
     call ScreenChar

     pop cx
     pop ax
     popf
     ret
ChangeLives ENDP

CheckLife PROC
     ; checks if the ball is below the paddle and resets it if it is
     pushf
     push ax
     push cx
     push si

     mov ball_r[0], 23 ; reset the ball to the original location and direction
     mov ball_c[0], 39
     mov ball_vert[0], -1
     call StartBall ; print the ball

     mov ch, 24
     mov al, 32
     mov ah, 0
     mov si, 0
     jmp cond
top:
     mov cl, paddle_locs[si]
     call ScreenChar
     inc si
cond:
     cmp si, 9
     jl top

     mov si, 0 ; reset the paddle location to the starting one
     mov cx, 36
     jmp cond2
top2:
     mov paddle_locs[si], cl
     inc cx
     inc si
cond2:
     cmp si, 9
     jl top2

     call PrintPaddle ; print out the paddle

     mov cl, lives[0] ; substract a life
     sub cl, 1
     mov lives[0], cl

     call ChangeLives

     mov lost_life[0], 1 ; show that a life has been lost

     pop si
     pop cx
     pop ax
     popf
     ret
CheckLife ENDP

ChangeScore PROC
     ; changes the score and invokes a screenchar to reflect that change
     pushf
     push ax
     push cx

     cmp score_ones[0], 9 ; if score in ones is nine need to update tens too
     jl ones

     mov score_ones[0], 0 ; set ones to 0
     inc score_tens ; inc tens by one

     mov al, 48
     add al, score_tens[0] ; output tens
     mov ah, ball_color[0]
     mov ch, score_r[0]
     mov cl, score_tc[0]
     call ScreenChar

     mov al, 48
     mov ah, ball_color[0] ; output 0 in ones
     mov ch, score_r[0]
     mov cl, score_c[0]
     call ScreenChar

     jmp done

ones:

     inc score_ones ; if not 9 inc ones by one

     mov al, 48
     add al, score_ones[0] ; output ones
     mov ah, ball_color[0]
     mov ch, score_r[0]
     mov cl, score_c[0]
     call ScreenChar

done:
     pop cx
     pop ax
     popf
     ret
ChangeScore ENDP

BrickSound PROC
     ; makes the sound for the paddle and sets timer to appropriate length
     pushf
     push dx

     mov dx, brick_hz[0]
     call PlayCount

     call SpeakerOn

     mov dx, 0
     mov dl, 6
     call SetTimer

     pop dx
     popf
     ret
BrickSound ENDP

DeleteBricks PROC
     ; deletes five bricks for every hit
     ; ax has the proper printing stuff
     ; es:[di] has the location of the hit block
     ; cl has col number
     ; ch has row number
     pushf
     push ax
     push cx
     push si

     cmp cl, 80
     jl norm

     dec cl

norm:
     mov al, cl
     mov cl, 5

     div cl ; this basically just mods the col number by 5
     mul cl

     mov cl, al ; now cl contains the first char of the brick

     mov si, 0
     jmp cond
top:
     call ScreenChar ; print space over every brick
     inc cl
     inc si
cond:
     cmp si, 5
     jl top

     call ChangeScore ; change the score
     call BrickSound

     pop si
     pop cx
     pop ax
     popf
     ret
DeleteBricks ENDP

CheckSide PROC
     ; es:[di] is the location of the ball in the memory mapped I/O
     pushf
     push ax
     push bx
     push di

     add cl, ball_hori[0]

     push ax ; save value of ax

     call RowCol2Index ; set row col to actual location in memory

     mov di, ax ; save offset of the location wanted

     pop ax ; get value back

     mov bl, block_mid_char[0]
     mov ax, es:[di]
     cmp al, bl ; check if location is a brick
     jne nobrick

     mov bx, 0
     mov bl, ball_hori[0] ; flip horizontal movement
     mov al, -1
     mul bl
     mov ball_hori[0], al

     mov ah, 0 ; change the brick to a space
     mov al, 32
     ;mov es:[di], ax
     call DeleteBricks

     mov contact[0], 1 ; chnage contact to 1

nobrick:
     pop di
     pop bx
     pop ax
     popf
     ret
CheckSide ENDP

CheckTB PROC
     ; es:[di] is the location of the ball in the memory mapped I/O
     pushf
     push ax
     push bx
     push cx
     push di
     push si

     add ch, ball_vert[0]

     push ax ; save value of ax

     call RowCol2Index ; set row col to actual location in memory

     mov di, ax ; save offset of the location wanted

     pop ax ; get value back

     mov bl, block_mid_char[0]
     mov ax, es:[di]
     cmp al, bl ; check if location is a brick
     jne nobrick

     mov bl, ball_vert[0] ; flip vertical movement
     mov al, -1
     mul bl
     mov ball_vert[0], al

     mov ah, 0 ; change brick to a space
     mov al, 32
     ;mov es:[di], ax
     call DeleteBricks

     mov contact[0], 1 ; change contact to 1

nobrick:
     pop si
     pop di
     pop cx
     pop bx
     pop ax
     popf
     ret
CheckTB ENDP

CheckCorner PROC
     ; es:[di] is the location of the ball in the memory mapped I/O
     pushf
     push ax
     push bx
     push di
     push si

     add ch, ball_vert[0]
     add cl, ball_hori[0]

     push ax ; save value of ax

     call RowCol2Index ; set row col to actual location in memory

     mov di, ax ; save offset of the location wanted

     pop ax ; get value back

     mov bl, block_mid_char[0]
     mov ax, es:[di]
     cmp al, bl ; check if location is a brick
     jne nobrick

     mov bl, ball_vert[0] ; flip vertical movement
     mov al, -1
     mul bl
     mov ball_vert[0], al

     mov bl, ball_hori[0] ; flip horizontal movement
     mov al, -1
     mul bl
     mov ball_hori[0], al


     mov ah, 0 ; change brick to a space
     mov al, 32
     ;mov es:[di], ax
     call DeleteBricks

nobrick:
     pop si
     pop di
     pop bx
     pop ax
     popf
     ret
CheckCorner ENDP

CheckBricks PROC
     ; checks if there is a brick in the three hittable spots based on direction
     ; of the ball
     ; ch is the row of the ball
     ; cl is the col of the ball
     pushf
     push ax
     push cx
     push di
     push es

     mov di, 0B800h
     mov es, di ; set es to memory mapped I/O

     push ax ; save value of ax

     call RowCol2Index ; set row col to actual location in memory

     mov di, ax ; save offset of the location wanted

     pop ax ; get value back

     call CheckSide ; check if there is a side hit
     call CheckTB ; check if there is a top or bottom hit
     cmp contact[0], 1 ; if contact corner not a possible hit
     je nocorner

     ;call CheckCorner ; check if there is a corner hit if not TB or side hit

nocorner:

     mov contact[0], 0

     pop es
     pop di
     pop cx
     pop ax
     popf
     ret
CheckBricks ENDP

WallSound PROC
     ; makes the sound for the paddle and sets timer to appropriate length
     pushf
     push dx

     mov dx, wall_hz[0]
     call PlayCount

     call SpeakerOn

     mov dx, 0
     mov dl, 6
     call SetTimer

     pop dx
     popf
     ret
WallSound ENDP

MoveBall PROC
     ; moves ball on the clock based on the ball_hori/vert and chnages
     ; directions on wall contact
     push ax
     push bx
     push cx
     push dx

     mov ch, ball_r[0] ; put the r and c in the r and c holders
     mov cl, ball_c[0]
     mov ax, 32
     mov ah, 0
     call ScreenChar ; replace the ball with a space

     cmp ch, 25
     jl inplay
     call CheckLife
     jmp done

inplay:

     call CheckBricks ; checks if a brick is in a hittable position

     cmp ch, 0 ; if top reverse the ball direction vertically
     jg nottop

     mov ball_vert[0], 1
     call WallSound

nottop:
     cmp ch, 23
     jne nopad

     call CheckPaddle

nopad:
     cmp cl, 1 ; if it is the left wall flip the ball direction horizontally
     jle side

     cmp cl, 79 ; if it is the right wall flip the ball direction horizontally
     jl notside
side:

     mov bl, ball_hori[0]
     mov al, -1
     mul bl
     mov ball_hori[0], al
     call WallSound


notside:
     mov bh, ball_vert[0] ; move row and col adjusters into bh and bl
     mov bl, ball_hori[0]

     add ch, bh ; add the r/c adjusters to ch and cl
     add cl, bl

     cmp cl, 0 ; check if the adjustment was too much and make sure it doesn't
     jge under ; go under 0

     mov cl, 0

under:
     cmp cl, 79 ; check if the adjustment was too much and make sure it doesn't
     jle over ; go over 79

     mov cl, 79

over:
     mov ball_r[0], ch ; set r and c to new r and c
     mov ball_c[0], cl

     mov al, ball_char[0] ; mov the ball char and color into ah and al
     mov ah, ball_color[0]
     call ScreenChar ; move the ball in the proper direction

done:
     pop dx
     pop cx
     pop bx
     pop ax
     ret
MoveBall ENDP

GameHandler PROC
     ; this is gonna replace the clock and handle the ball, collisions and score
     sti
     push ax
     push dx

     cmp timer[0], 0
     je cont

     call SpeakerOff
     dec timer[0]

cont:

     cmp tick[0], 3
     je nomove

     cmp lost_life[0], 1
     je done

     call MoveBall

     inc tick
     jmp done

nomove:

     mov tick[0], 0

done:

     pop dx
     pop ax
     iret
GameHandler ENDP

InstallHandler PROC
     ; installs the GameHandler into the 1ch interrupt
     ; al needs to be 1ch
     ; dx is offset of the GameHandler
     pushf
     push ax
     push dx

     mov al, bios_clock_int[0]
     mov dx, OFFSET GameHandler
     call SetInterruptVector

     pop dx
     pop ax
     popf
     ret
InstallHandler ENDP

CreateBoard PROC
     ; creates the original board by putting spaces basically everywhere
     ; and sets ball to near the bottom in the middle
     pushf
     push ax
     push cx

     mov ax, 32 ; move space into ax
     mov ah, 0 ; make sure attributes stay default
     mov cx, 0 ; set cx to zero so it can loop for every row/col
     jmp cond
top:
     call ScreenChar
     cmp cl, 79
     je up
     inc cl
     jmp cond
up:
     inc ch
     mov cl, 0
cond:
     cmp ch, 25
     jl top

     call StartBall ; set up ball
     call PrintPaddle ; set up paddle
     call PrintBlocks ; set up blocks
     call ChangeScore ; set up score
     call ChangeLives ; set up lives

     pop cx
     pop ax
     popf
     ret
CreateBoard ENDP

ClearPaddle PROC
     ; clears the current paddle with spaces
     pushf
     push ax
     push cx
     push si

     mov ch, 24 ; paddle stays at r 24 the whole game
     mov al, 32 ; clears paddle with space
     mov ah, paddle_color[0] ; this is just white with black background no blink
     mov si, 0
     jmp cond
top:
     mov cl, paddle_locs[si] ; paddle goes six rows starting at 37
     call ScreenChar
     inc si
cond:
     cmp si, 9
     jl top

     pop si
     pop cx
     pop ax
     popf
     ret
ClearPaddle ENDP

MovePaddleRight PROC
     ; moves the paddle right on the d key call
     pushf
     push bx
     push si

     mov bl, paddle_locs[8] ; if paddle is off the edge don't move it
     cmp bl, 79
     jge done

     call ClearPaddle ; replace the paddle with spaces

     mov bx, 0
     mov si, 0
     jmp cond
top:
     mov bl, paddle_locs[si] ; move paddle over to the right
     add bl, 2
     mov paddle_locs[si], bl
     inc si
cond:
     cmp si, 9
     jl top

     call PrintPaddle ; print the paddle

done:
     pop si
     pop bx
     popf
     ret
MovePaddleRight ENDP

MovePaddleLeft PROC
     ; moves the paddle left on the left arrow key call
     pushf
     push bx
     push si

     mov bl, paddle_locs[0] ; check if paddle is off the edge if so don't move
     cmp bl, 1
     jle done

     call ClearPaddle ; replace paddle with spaces

     mov bx, 0
     mov si, 0
     jmp cond
top:
     mov bl, paddle_locs[si] ; move paddle to the left
     add bl, -2
     mov paddle_locs[si], bl
     inc si
cond:
     cmp si, 9
     jl top

     call PrintPaddle ; print paddle in new loc

done:
     pop si
     pop bx
     popf
     ret
MovePaddleLeft ENDP

WaitToStart PROC
     ; calls the non echo char read just so the game waits till you are ready to
     ; start
     pushf
     push ax

     mov ah, 10h
     int 16h

     pop ax
     popf
     ret
WaitToStart ENDP

WinOut PROC
     ; outputs a win message
     pushf
     push ax
     push cx
     push si

     mov ch, win_r[0] ; mov win print stuff into proper registers
     mov cl, win_c[0]
     mov si, 0
     mov ah, ball_color[0] ; this is just white

     jmp cond
top:
     mov al, win_mes[si] ; print out the message
     call ScreenChar
     inc si
     inc cl
cond:
     cmp si, 8
     jl top

     pop si
     pop cx
     pop ax
     popf
     ret
WinOut ENDP

LostOut PROC
     ; outputs a lose message
     pushf
     push ax
     push cx
     push si

     mov ch, win_r[0] ; win and lose messages happen in the same place
     mov cl, win_c[0]
     mov si, 0
     mov ah, ball_color[0] ; this is white

     jmp cond
top:
     mov al, los_mes[si] ; print lose message
     call ScreenChar
     inc si
     inc cl
cond:
     cmp si, 8
     jl top

     pop si
     pop cx
     pop ax
     popf
     ret
LostOut ENDP

Splash PROC
     ; Splash screen output
     pushf
     push ax
     push cx
     push si

     mov ch, win_r[0] ; win and splash messages happen in the same place
     mov cl, win_c[0]
     mov si, 0
     mov ah, ball_color[0] ; this is white

     jmp cond
top:
     mov al, splash_mes[si] ; print splash message
     call ScreenChar
     inc si
     inc cl
cond:
     cmp si, 8
     jl top

     pop si
     pop cx
     pop ax
     popf
     ret
Splash ENDP

ClearSplash PROC
     ; clears the splash message
     pushf
     push ax
     push cx
     push si

     mov ch, win_r[0] ; win and splash messages happen in the same place
     mov cl, win_c[0]
     mov si, 0
     mov ah, ball_color[0] ; this is white
     mov al, 32 ; use space to clear the message

     jmp cond
top:
     call ScreenChar
     inc si
     inc cl
cond:
     cmp si, 8
     jl top

     pop si
     pop cx
     pop ax
     popf
     ret
ClearSplash ENDP

Delay PROC
     pushf
     push cx

top:
     push cx
     mov cx, 65535
top2:
     loop top2

     pop cx
     loop top

     pop cx
     popf
     ret
Delay ENDP

Sticcato PROC
     ; makes notes sound sticcato
     pushf
     push cx
     call SpeakerOff

     mov cx, 1
     call Delay

     call SpeakerOn
     pop cx
     popf
     ret
Sticcato ENDP

PlayIntro PROC
     pushf
     push bx
     push cx
     push dx
     push si

     mov bx, 0
     mov cx, 0
     mov si, 0
     jmp cond
top:

     mov bl, intro_key[si]
     mov dx, notes[bx]
     call PlayCount

     mov cl, intro_length[si]
     call delay

     call sticcato

     inc si
cond:
     cmp si, 20
     jl top

     pop si
     pop dx
     pop cx
     pop bx
     popf
     ret
PlayIntro ENDP

PlayLoss PROC
     pushf
     push bx
     push cx
     push dx
     push si

     mov dx, 0
     mov bx, 0
     mov cx, 0
     mov si, 0
     jmp cond
top:

     mov bl, loss_key[si]
     mov dx, notes[bx]
     call PlayCount

     mov cl, loss_length[si]
     call delay

     call sticcato

     inc si
cond:
     cmp si, 13
     jl top

     pop si
     pop dx
     pop cx
     pop bx
     popf
     ret
PlayLoss ENDP

PlayWin PROC
     pushf
     push bx
     push cx
     push dx
     push si

     mov dx, 0
     mov bx, 0
     mov cx, 0
     mov si, 0
     jmp cond
top:

     mov bl, win_key[si]
     mov dx, notes[bx]
     call PlayCount

     mov cl, win_length[si]
     call delay

     call sticcato

     inc si
cond:
     cmp si, 19
     jl top

     pop si
     pop dx
     pop cx
     pop bx
     popf
     ret
PlayWin ENDP

main PROC

     mov ax, @data   ; set up code
     mov ds, ax

     mov ax, 6
     call RandRange
     sub al, 3
     mov ball_hori[0], al

     call CreateBoard
     call Splash

     call SpeakerOn
     call PlayIntro
     call SpeakerOff

     call WaitToStart

     call ClearSplash

     mov al, bios_clock_int[0]
     call GetInterruptVector ; get the vector for the clock interrupt we want to use

     call SaveVector ; can call handler too just not set up yet

     call InstallHandler ; install the GameHandler at the proper place

     mov ax, 0
     jmp cond
top:
     cmp lost_life[0], 1
     jne notlost
     mov lost_life[0], 0

notlost:
     cmp lives[0], 0
     jle lost

     cmp score_tens[0], 8
     je win

     mov ah, 10h ; non echo character read in
     int 16h

     cmp al, 61
     jne demo

     mov score_ones[0], 9
     mov score_tens[0], 7

demo:

     cmp al, 97 ; uses a to go left
     jne notleft

     call MovePaddleLeft

notleft:

     cmp al, 100 ; uses d to go right
     jne notright

     call MovePaddleRight

notright:
cond:
     cmp al, 113 ; if the character us q then quit
     jne top

     jmp done

win:

     call WinOut
     call RestoreVector ; Puts the orginal vector back into the IVT
     call PlayWin
     jmp done

lost:

     call LostOut
     call RestoreVector ; Puts the orginal vector back into the IVT
     call PlayLoss

done:
     call RestoreVector ; Puts the orginal vector back into the IVT
     call SpeakerOff

     mov ax, 4C00h   ; terminate code
     int 21h

main ENDP
END main
