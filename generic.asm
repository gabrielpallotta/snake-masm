; #########################################################################
;
;             GENERIC.ASM is a roadmap around a standard 32 bit 
;              windows application skeleton written in MASM32.
;
; #########################################################################

;           Assembler specific instructions for 32 bit ASM code

      .386                   ; minimum processor needed for 32 bit
      .model flat, stdcall   ; FLAT memory model & STDCALL calling
      option casemap :none   ; set code to case sensitive

; #########################################################################

      ; ---------------------------------------------
      ; main include file with equates and structures
      ; ---------------------------------------------
      include \masm32\include\windows.inc

      ; -------------------------------------------------------------
      ; In MASM32, each include file created by the L2INC.EXE utility
      ; has a matching library file. If you need functions from a
      ; specific library, you use BOTH the include file and library
      ; file for that library.
      ; -------------------------------------------------------------

      include \masm32\include\user32.inc
      include \masm32\include\kernel32.inc
      include \masm32\include\gdi32.inc

      includelib \masm32\lib\user32.lib
      includelib \masm32\lib\kernel32.lib
      includelib \masm32\lib\gdi32.lib

; #########################################################################

; ------------------------------------------------------------------------
; MACROS are a method of expanding text at assembly time. This allows the
; programmer a tidy and convenient way of using COMMON blocks of code with
; the capacity to use DIFFERENT parameters in each block.
; ------------------------------------------------------------------------

      ; 1. szText
      ; A macro to insert TEXT into the code section for convenient and 
      ; more intuitive coding of functions that use byte data as text.

      szText MACRO Name, Text:VARARG
        LOCAL lbl
          jmp lbl
            Name db Text,0
          lbl:
        ENDM

      ; 2. m2m
      ; There is no mnemonic to copy from one memory location to another,
      ; this macro saves repeated coding of this process and is easier to
      ; read in complex code.

      m2m MACRO M1, M2
        push M2
        pop  M1
      ENDM

      ; 3. return
      ; Every procedure MUST have a "ret" to return the instruction
      ; pointer EIP back to the next instruction after the call that
      ; branched to it. This macro puts a return value in eax and
      ; makes the "ret" instruction on one line. It is mainly used
      ; for clear coding in complex conditionals in large branching
      ; code such as the WndProc procedure.

      return MACRO arg
        mov eax, arg
        ret
      ENDM

; #########################################################################

; ----------------------------------------------------------------------
; Prototypes are used in conjunction with the MASM "invoke" syntax for
; checking the number and size of parameters passed to a procedure. This
; improves the reliability of code that is written where errors in
; parameters are caught and displayed at assembly time.
; ----------------------------------------------------------------------

        WinMain PROTO :DWORD,:DWORD,:DWORD,:DWORD
        WndProc PROTO :DWORD,:DWORD,:DWORD,:DWORD
        TopXY PROTO   :DWORD,:DWORD

; declaração de constantes
.const
        IDB_MAIN  equ 1   ; numero do bitmap
        WM_FINISH equ WM_USER+100h
        BOARD_HEIGHT equ 15
        BOARD_WIDTH equ 15
        BOARD_COUNT equ BOARD_HEIGHT * BOARD_WIDTH
        TILE_SIZE equ 32
        
; #########################################################################

; ------------------------------------------------------------------------
; This is the INITIALISED data section meaning that data declared here has
; an initial value. You can also use an UNINIALISED section if you need
; data of that type [ .data? ]. Note that they are different and occur in
; different sections.
; ------------------------------------------------------------------------

    .data
        szDisplayName db "Snake",0
        CommandLine   dd 0
        hWnd          dd 0
        hInstance     dd 0

        sprite        dd 0

    .data?
        ; coordenadas
        fruit         POINT<> 
        snake         POINT<> BOARD_COUNT  dup(?) 
        


        ; handle dos bitmaps
        hBmpSnake     dd      ?
        hBmpBg        dd      ?
        hBmpFruit     dd      ?
 
        ; threads
        ThreadID      DWORD   ?
        hEventStart   HANDLE  ?

; #########################################################################

; ------------------------------------------------------------------------
; This is the start of the code section where executable code begins. This
; section ending with the ExitProcess() API function call is the only
; GLOBAL section of code and it provides access to the WinMain function
; with the necessary parameters, the instance handle and the command line
; address.
; ------------------------------------------------------------------------

    .code

; -----------------------------------------------------------------------
; The label "start:" is the address of the start of the code section and
; it has a matching "end start" at the end of the file. All procedures in
; this module must be written between these two.
; -----------------------------------------------------------------------

start:
    invoke GetModuleHandle, NULL ; provides the instance handle
    mov hInstance, eax

    invoke GetCommandLine        ; provides the command line address
    mov CommandLine, eax

    invoke WinMain,hInstance,NULL,CommandLine,SW_SHOWDEFAULT
    
    invoke ExitProcess,eax       ; cleanup & return to operating system

; #########################################################################

WinMain proc hInst     :DWORD,
             hPrevInst :DWORD,
             CmdLine   :DWORD,
             CmdShow   :DWORD

        ;====================
        ; Put LOCALs on stack
        ;====================

        LOCAL wc   :WNDCLASSEX
        LOCAL msg  :MSG

        LOCAL Wwd  :DWORD
        LOCAL Wht  :DWORD
        LOCAL Wtx  :DWORD
        LOCAL Wty  :DWORD

        szText szClassName,"Generic_Class"

        ;==================================================
        ; Fill WNDCLASSEX structure with required variables
        ;==================================================

        mov wc.cbSize,         sizeof WNDCLASSEX
        mov wc.style,          CS_HREDRAW or CS_VREDRAW \
                               or CS_BYTEALIGNWINDOW
        mov wc.lpfnWndProc,    offset WndProc      ; address of WndProc
        mov wc.cbClsExtra,     NULL
        mov wc.cbWndExtra,     NULL
        m2m wc.hInstance,      hInst               ; instance handle
        mov wc.hbrBackground,  COLOR_BTNFACE+1     ; system color
        mov wc.lpszMenuName,   NULL
        mov wc.lpszClassName,  offset szClassName  ; window class name
          invoke LoadIcon,hInst,500    ; icon ID   ; resource icon
        mov wc.hIcon,          eax
          invoke LoadCursor,NULL,IDC_ARROW         ; system cursor
        mov wc.hCursor,        eax
        mov wc.hIconSm,        0

        invoke RegisterClassEx, ADDR wc     ; register the window class

        ;================================
        ; Centre window at following size
        ;================================

        mov Wwd, TILE_SIZE * BOARD_WIDTH
        mov Wht, TILE_SIZE * BOARD_HEIGHT

        invoke GetSystemMetrics,SM_CXSCREEN ; get screen width in pixels
        invoke TopXY,Wwd,eax
        mov Wtx, eax

        invoke GetSystemMetrics,SM_CYSCREEN ; get screen height in pixels
        invoke TopXY,Wht,eax
        mov Wty, eax

        ; ==================================
        ; Create the main application window
        ; ==================================
        invoke CreateWindowEx,WS_EX_OVERLAPPEDWINDOW,
                              ADDR szClassName,
                              ADDR szDisplayName,
                              WS_OVERLAPPEDWINDOW,
                              Wtx,Wty,Wwd,Wht,
                              NULL,NULL,
                              hInst,NULL

        mov   hWnd,eax  ; copy return value into handle DWORD

        invoke ShowWindow,hWnd,SW_SHOWNORMAL      ; display the window
        invoke UpdateWindow,hWnd                  ; update the display

      ;===================================
      ; Loop until PostQuitMessage is sent
      ;===================================

        StartLoop:
            invoke GetMessage,ADDR msg,NULL,0,0         ; get each message
            cmp eax, 0                                  ; exit if GetMessage()
            je ExitLoop                                 ; returns zero
            invoke TranslateMessage, ADDR msg           ; translate it
            invoke DispatchMessage,  ADDR msg           ; send it to message proc
            jmp StartLoop
        ExitLoop:

      return msg.wParam

WinMain endp

; #########################################################################

WndProc proc hWin   :DWORD,
             uMsg   :DWORD,
             wParam :DWORD,
             lParam :DWORD

LOCAL        hDC    :DWORD
LOCAL        Ps     :PAINTSTRUCT
LOCAL        hMenDC :HDC
LOCAL        rect   :RECT

; -------------------------------------------------------------------------
; Message are sent by the operating system to an application through the
; WndProc proc. Each message can have additional values associated with it
; in the two parameters, wParam & lParam. The range of additional data that
; can be passed to an application is determined by the message.
; -------------------------------------------------------------------------

    .if uMsg == WM_CREATE
    ; --------------------------------------------------------------------
    ; This message is sent to WndProc during the CreateWindowEx function
    ; call and is processed before it returns. This is used as a position
    ; to start other items such as controls. IMPORTANT, the handle for the
    ; CreateWindowEx call in the WinMain does not yet exist so the HANDLE
    ; passed to the WndProc [ hWin ] must be used here for any controls
    ; or child windows.
    ; --------------------------------------------------------------------

    
    invoke Random BOARD_WIDTH
    mov fruit.x, eax

    invoke Random BOARD_HEIGHT
    mov fruit.y, eax

    mov position.x, 200
    mov position.y, 150
    mov x, 100

    ; randomiza a fruta
    invoke Random BOARD_COUNT
    mov fruit, eax

    invoke CreateEvent, NULL, FALSE, FALSE, NULL
    mov    hEventStart, eax

    invoke LoadBitmap, hInstance, IDB_MAIN
    mov    hBitmap, eax

    .elseif uMsg == WM_DESTROY
    ; ----------------------------------------------------------------
    ; This message MUST be processed to cleanly exit the application.
    ; Calling the PostQuitMessage() function makes the GetMessage()
    ; function in the WinMain() main loop return ZERO which exits the
    ; application correctly. If this message is not processed properly
    ; the window disappears but the code is left in memory.
    ; ----------------------------------------------------------------
        invoke DeleteObject, hBitmap

        invoke PostQuitMessage,NULL
        return 0 

    .elseif uMsg == WM_KEYDOWN
        .if wParam == VK_RIGHT
            add   x, 3
        .endif
        .if x > 200
            mov x, 200
        .endif

    .elseif uMsg == WM_KEYUP
        .if wParam == VK_RIGHT
          invoke  InvalidateRect, hWnd, NULL, TRUE
        .endif

    .elseif uMsg == WM_FINISH
        .if sprite == 0
            mov x, 100
            mov y, 0
        .elseif sprite == 1
            mov x, 120
            mov y, 30
        .elseif sprite == 2
            mov x, 150
            mov y, 30
        .elseif sprite == 3
            mov x, 150
            mov y, 60
        .endif
    
    invoke  InvalidateRect, hWnd, NULL, TRUE

    .elseif uMsg == WM_PAINT
        invoke BeginPaint, hWin, ADDR Ps
        mov    hDC, eax
        
        invoke CreateCompatibleDC, hDC
        mov    hBgDC, eax


        ; desenha o background na teoria
        invoke SelectObject, hBgDC, hBmpBg
        mov ebx, 0
        .while ebx < BOARD_HEIGHT
            mov ecx, 0
            .while ecx < BOARD_WIDTH
                invoke BitBlt, hDC, ecx * TILE_SIZE, ebx * TILE_SIZE, TILE_SIZE, TILE_SIZE, hBgDC, 0, 0, SRCCOPY
                inc ecx
            .endw
            inc ebx
        .endw

        ; desenha a fruta na teoria
        invoke SelectObject, hBgDC, hBmpFruit
        invoke BitBlt, hDC, fruit.x * TILE_SIZE, fruit.y * TILE_SIZE, TILE_SIZE, TILE_SIZE, hBgDC, 0, 0, SRCCOPY

        ; desenha a cobra na teoria
        invoke SelectObject, hBgDC, hBmpSnake
        mov ebx, 0
        .while snake[ebx] != -1
            invoke BitBlt, hDC, snake[ebx].x * TILE_SIZE, snake[ebx].y * TILE_SIZE, TILE_SIZE, TILE_SIZE, hBgDC, 0, 0, SRCCOPY
            inc ebx
        .endw

        invoke DeleteDC, hBgDC

        invoke EndPaint, hWin, ADDR Ps
        return 0
    .endif

    invoke DefWindowProc,hWin,uMsg,wParam,lParam
    ; --------------------------------------------------------------------
    ; Default window processing is done by the operating system for any
    ; message that is not processed by the application in the WndProc
    ; procedure. If the application requires other than default processing
    ; it executes the code when the message is trapped and returns ZERO
    ; to exit the WndProc procedure before the default window processing
    ; occurs with the call to DefWindowProc().
    ; --------------------------------------------------------------------

    ret

WndProc endp

; ########################################################################

TopXY proc wDim:DWORD, sDim:DWORD

    ; ----------------------------------------------------
    ; This procedure calculates the top X & Y co-ordinates
    ; for the CreateWindowEx call in the WinMain procedure
    ; ----------------------------------------------------

    shr sDim, 1      ; divide screen dimension by 2
    shr wDim, 1      ; divide window dimension by 2
    mov eax, wDim    ; copy window dimension into eax
    sub sDim, eax    ; sub half win dimension from half screen dimension

    return sDim

TopXY endp

; ########################################################################

ThreadProc PROC USES ecx Param:DWORD
    invoke WaitForSingleObject, hEventStart, 500 ; 500 eh o tempo
    .if eax == WAIT_TIMEOUT
        inc   sprite
        .if sprite == 4
            mov   sprite, 0
        .endif
        invoke  SendMessage, hWnd, WM_FINISH, NULL, NULL
    .endif
    jmp   ThreadProc
    ret
ThreadProc endp

Random proc Range:DWORD   
    LOCAL TempInt:DWORD
    LOCAL RMax:DWORD

    mov eax, TRAND_MAX;
    mov RMax, eax;
      
    mov  eax, seed;
    imul eax, eax,343FDh;
    add  eax, 269EC3h;
    mov  seed,eax;
    sar  eax,10h;
    and  eax,7FFFh;

    mov TempInt, eax;

    fild TempInt;
    fild RMax;
    fdivp st(1), st(0);
    fild Range;
    fmulp st(1), st(0);
    fistp TempInt; 
 
    mov eax, TempInt;
    ret
    
Random endp

end start