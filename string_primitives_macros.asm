TITLE Program6     (template.asm)

; Author: Robert Rouleau
; Last Modified: 3/13/22
; OSU email address: roulearo@oregonstate.edu
; Course number/section:   CS271 Section 400
; Project Number: 6                Due Date: 3/13/22
; Description: This program collects 10 signed integers as ascii digits, validates that all of the characters are digits, then displays the
;				numbers, their sum, and their truncated average.

INCLUDE Irvine32.inc

; ---------------------------------------------------------------------------------
; Name: mGetString
;
; Displays a prompt and collects user input with ReadString.
;
; Preconditions: None.
;
; Postconditions: None.
;
; Receives: mPrompt = address of string.
;			userInput = address of string to store input read.
;			inputSize = size of userInput.
;			byteCount = address of DWORD to store number of characters read.
;
; returns: userInput = the string entered by the user.
;		   byteCount = the number of characters entered by the user.
; ---------------------------------------------------------------------------------

mGetString	MACRO mPrompt, userInput, inputSize, byteCount

  push		EDX
  push		ECX
  push		EAX

  ; Display a prompt.
  mov		EDX, mPrompt
  call		WriteString

  ; Get user input and save it in memory.
  mov		EDX, userInput
  mov		ECX, inputSize - 1
  call		ReadString
  mov		byteCount, EAX

  pop		EAX
  pop		ECX
  pop		EDX

ENDM

; ---------------------------------------------------------------------------------
; Name: mDisplayString
;
; Displays a string provided as argument
;
; Preconditions: None.
;
; Postconditions: None.
;
; Receives: data = address of string to be displayed
;
; returns: Prints string to console.
; ---------------------------------------------------------------------------------
mDisplayString	MACRO data

  push	EDX

  ; Display a string from memory.
  mov	EDX, data
  call	WriteString

  pop	EDX

ENDM

; ASCII value of + and - saved as constants to aid readability.
PLUS = 43
HYPHEN = 45

.data
programTitle			BYTE		"Designing low-level I/O procedures and Macros",13,10,"Written by: Robert Rouleau",13,10,0
instructions			BYTE		"Please enter 10 integers (sign optional).",13,10,"Each number must fit a 32-bit register.",13,10,
									"All valid numbers will be displayed, followed by their sum and truncated average",13,10,0
promptNumbers			BYTE		"Enter a number: ",0
userInput				BYTE		30 DUP(?)
byteCount				DWORD		?
numericValues			SDWORD		10 DUP(?)
stringValue				BYTE		12 DUP(?)
errorMessage			BYTE		"The number you entered is invalid.",0
errorFound				BYTE		0
displayNumbersMessage	BYTE		"The numbers you entered are: ",13,10,0
comma					BYTE		", ",0
sumMessage				BYTE		"The sum of the numbers you entered is: ",0
sumNumeric				SDWORD		?
averageNumeric			SDWORD		?
averageMessage			BYTE		"The truncated average is: ",0

.code
main PROC
  
  ; Introduce the program.
  mov					EDX, OFFSET programTitle
  call					WriteString
  call					CrLf

  ; Display instructions for the user.
  mov					EDX, OFFSET instructions
  call					WriteString
  call					CrLf

  ; Loop until 10 valid integers are read into memory.
  mov					ECX, 10
  mov					EDI, OFFSET numericValues
_get10Numbers:
  mov					errorFound, 0						; If invalid input was provided, errorFound should be reset to 0 to prevent infinite looping.
  push					OFFSET errorFound
  push					OFFSET errorMessage
  push					EDI
  push					OFFSET byteCount
  push					SIZEOF userInput
  push					OFFSET userInput
  push					OFFSET promptNumbers
  call					ReadVal
  cmp					errorFound, 0
  jne					_get10Numbers
  add					EDI, TYPE numericValues
  loop					_get10Numbers

  ; Prepare to display numbers and print a message that describes what is being printed.
  mov					ECX, 10
  mov					ESI, OFFSET numericValues
  mov					EDX, OFFSET displayNumbersMessage
  call					WriteString

  ; Loop until all 10 numbers are displayed.
_display10Numbers:
  push					OFFSET stringValue
  push					[ESI]
  call					WriteVal
  cmp					ECX, 1								
  je					_incESI								; If all the numbers have been printed, don't print another comma.
  mov					EDX, OFFSET comma
  call					WriteString
_incESI:
  add					ESI, TYPE numericValues
  loop					_display10Numbers
  call					CrLf

  ; Call a procedure that calculates the sum of the numbers entered.
  push					OFFSET numericValues
  push					OFFSET sumNumeric
  call					Sum

  ; Print a message that indicates the next number printed is a sum.
  mov					EDX, OFFSET sumMessage
  call					WriteString  

  ; Call a procedure that converts the SDWORD sum into a string and print it.
  push					OFFSET stringValue
  push					sumNumeric
  call					WriteVal
  call					CrLf

  ; Call a procedure that calculates the average of the numbers entered.
  push					sumNumeric
  push					OFFSET averageNumeric
  call					Average

  ; Print a message that indicates the next number printed is a truncated average.
  mov					EDX, OFFSET averageMessage
  call					WriteString

  ; Call a procedure that converts the SDWORD average into a string and print it.
  push					OFFSET stringValue
  push					averageNumeric
  call					WriteVal

	Invoke ExitProcess,0									; exit to operating system.
main ENDP

; ---------------------------------------------------------------------------------
; Name: ReadVal
; 
; This procedure invokes mGetString macro to collect user input. The input is then
; validated to ensure it only contains ASCII numbers, +, -, and is not too large
; to fit a 32-bit register or SDWORD. The numeric value is then stored in memory.
; If an invalid character is found, the user's input is discarded and an error
; message is displayed.
;
; Preconditions: None.
;
; Postconditions: None.
;
; Receives: address of errorFound (reference), address of errorMessage (reference), address of numericValues (reference),
;			address of byteCount (reference), SIZEOF userInput (value), address of userInput (reference), address of 
;			prompt that will be printed (reference).
;
; Returns: Invokes mGetString which changes the value in byteCount and userInput. Stores user's input in numericValues. 
; ---------------------------------------------------------------------------------
ReadVal PROC

  push					EBP
  mov					EBP, ESP
  push					ECX
  push					EBX
  push					EDX
  push					ESI
  push					EAX
  push					EDI

  ; Invoke mGetString macro to get user input in the form of a string of digits.
  mGetString			[EBP + 8], [EBP + 12], [EBP + 16], [EBP + 20]

  ; Validate the user's input, checking for a sign before entering validation loop
  mov					ESI, [EBP + 12]
  mov					EAX, 0
  lodsb
  mov					ECX, [EBP + 20]
  cmp					ECX, 0								; If the value in ECX is 0, then the user did not enter a number.
  je					_invalid
  dec					ECX
  cmp					AL, PLUS
  je					_validateSigned
  cmp					AL, HYPHEN
  je					_validateSigned
  inc					ECX
  
  ; Validate that all the characters are within 0-9 (ASCII)
_validateUnsigned:
  cmp					AL, 48
  jb					_invalid
  cmp					AL, 57
  ja					_invalid
  lodsb
  loop					_validateUnsigned
  jmp					_prepUnsignedConversion

 ; Validate that all the characters are within 0-9 (ASCII)
_validateSigned:
  lodsb
  cmp					AL, 48
  jb					_invalid
  cmp					AL, 57
  ja					_invalid
  loop					_validateSigned
  
  ; Convert the users input from ASCII representation to a numeric value. Signed Conversion begins at the second character.
_prepSignedConversion: 
  mov					ECX, [EBP + 20]
  dec					ECX
  mov					ESI, [EBP + 12]
  inc					ESI
  mov					EAX, 10
  xor					EBX, EBX
_signedConversion:
  mul					EBX		
  cmp					EDX, 0								; If EDX is not 0, the result of EAX x EBX was too large for a 32 bit register.
  jne					_invalid
  mov					EBX, EAX
  xor					EAX, EAX			
  lodsb
  sub					EAX, 48			
  add					EBX, EAX
  jc					_invalid							; If the carry flag is set after adding EAX and EBX, the result was too large for a 32 bit register.
  mov					EAX, 10
  loop					_signedConversion  
  jmp					_validateSize

  ; Convert the user's input from ASCII representation to a numeric value. Unsigned conversion begins with the first character.
_prepUnsignedConversion:
  mov					ECX, [EBP + 20]
  mov					ESI, [EBP + 12]
  mov					EAX, 10
  xor					EBX, EBX

_unsignedConversion:
  mul					EBX			
  cmp					EDX, 0								; If EDX is not 0, the result of EAX x EBX was too large for a 32 bit register.
  jne					_invalid
  mov					EBX, EAX
  xor					EAX, EAX			
  lodsb
  sub					EAX, 48			
  add					EBX, EAX
  jc					_invalid							; If the carry flag is set after adding EAX and EBX, the result was too large for a 32 bit register.
  mov					EAX, 10
  loop					_unsignedConversion  

  
  ; If the numeric value (ignoring sign) is greater than 2^31 it cannot fit in a SDWORD
_validateSize:
  cmp					EBX, 2147483648						; EBX = user's converted input
  ja					_invalid

  ; If the user input is positive it should not be greater than (2^31)-1
  mov					ESI, [EBP + 12]
  xor					EAX, EAX
  lodsb
  cmp					AL, HYPHEN		
  je					_storeValue
  cmp					EBX, 2147483647						; EBX = user's converted input
  ja					_invalid

   ; store the numeric value in memory
_storeValue:
  mov					EDI, [EBP + 24]
  mov					[EDI], EBX

  ; Check if the value stored should be negative or positive.
  mov					ESI, [EBP + 12]
  mov					EAX, 0
  lodsb
  cmp					AL, HYPHEN
  jne					_return
  neg					DWORD PTR [EDI]						; NEG multiplies operand by -1, so it must be converted to DWORD

_return:
  pop					EDI
  pop					EAX
  pop					ESI
  pop					EDX
  pop					EBX
  pop					ECX
  pop					EBP
  ret					28

  ; Print an error message and discard the user's input.
_invalid:
  mov					EDX, [EBP + 28]
  call					WriteString
  call					CrLf
  mov					ESI, [EBP + 32]
  mov					[ESI], DWORD PTR 1
  jmp					_return

ReadVal ENDP

; ---------------------------------------------------------------------------------
; Name: WriteVal
; 
; This procedure converts a numeric SDWORD value into a string of ascii digits and 
; invokes mDisplayString to display the string. The string used to hold the conversion
; is reset to null for future calls to this procedure.
;
; Preconditions: None.
;
; Postconditions: None.
;
; Receives: Address of stringValue (reference), numeric value to be converted and printed (value).
;
; Returns: Prints the numeric value it received as a string of ascii digits.
; ---------------------------------------------------------------------------------
WriteVal PROC
  push					EBP
  mov					EBP, ESP
  push					EAX
  push					EBX
  push					ECX
  push					EDI

  ; Checks if the number to be converted is 0, positive, or negative, and prepares for converting appropriately.
  mov					EDI, [EBP + 12]
  mov					EBX, 10
  mov					EAX, [EBP + 8]
  mov					ECX, 0
  cmp					EAX, 0
  je					_convertZero
  cdq
  cmp					EAX, 0
  jg					_posConversion
  mov					EDX, 0
  neg					EAX


_posConversion:
  idiv					EBX
  cmp					EDX, 0
  je					_posEvenDivision
  add					EDX, 48
  push					EDX
  inc					ECX
  mov					EDX, 0
  jmp					_posConversion

_posEvenDivision:
  cmp					EAX, 0
  je					_checkSign
  add					EDX, 48
  push					EDX
  mov					EDX, 0
  inc					ECX
  cmp					EAX, 10
  jge					_posConversion
  add					EAX, 48
  push					EAX
  inc					ECX
  jmp					_checkSign
  
; Invoke the mDisplay string macro to print the ascii representation of the SDWORD value to the output.
_checkSign:
  mov					EAX, [EBP + 8]
  cmp					EAX, 0
  jge					_storeString
  mov					EAX, HYPHEN
  stosb

_storeString:
  pop					EAX
  stosb
  loop					_storeString

  mDisplayString		[EBP + 12]
  

  ; Clear the value in string to prevent extra numbers being displayed
  mov					ECX, 12
  mov					EDI, [EBP + 12]
_clearString:
  mov					EAX, 0
  stosb
  loop					_clearString

  pop					EDI
  pop					ECX
  pop					EBX
  pop					EAX
  pop					EBP
  ret					8

_convertZero:
  add					EAX, 48
  push					EAX
  inc					ECX
  jmp					_storeString
WriteVal ENDP


; ---------------------------------------------------------------------------------
; Name: Sum
; 
; This procedures adds all the numbers it receives and stores the sum in memory.
;
; Preconditions: None.
;
; Postconditions: None.
;
; Receives: address of numericValues (reference), address of sumNumeric (reference) 
;
; Returns: Stores the sum of all the numbers in numericValues in sumNumeric.
; ---------------------------------------------------------------------------------
Sum PROC
  push					EBP
  mov					EBP, ESP
  push					ESI
  push					EDI
  push					EAX
  push					ECX
  
  mov					EDI, [EBP + 8]
  mov					ESI, [EBP + 12]
  mov					EAX, [ESI]
  mov					ECX, 9

  ; Add the numbers to get the sum
_getSum:
  add					ESI, 4
  add					EAX, [ESI]
  loop					_getSum
  mov					[EDI], EAX

  pop					ECX
  pop					EAX
  pop					EDI
  pop					ESI
  pop					EBP
  ret					8
Sum ENDP


; ---------------------------------------------------------------------------------
; Name: Average
; 
; This procedure calculates the average of the user's numbers by dividing the sum by 10.
;
; Preconditions: None.
;
; Postconditions: None.
;
; Receives: sumNumeric (value), address of averageNumeric (reference)
;
; Returns: Stores the calculated average in averageNumeric.
; ---------------------------------------------------------------------------------
Average PROC
  push					EBP
  mov					EBP, ESP
  push					EAX
  push					EBX
  push					EDI

  ; Divide the sum by 10 and store the result in memory.
  mov					EDI, [EBP + 8]
  mov					EAX, [EBP + 12]
  mov					EBX, 10
  cdq
  idiv					EBX
  mov					[EDI], EAX

  pop					EDI
  pop					EBX
  pop					EAX
  pop					EBP
  ret					8
Average ENDP

END main
