; #########################################################################
;
;                               Snake game
;                              Is it clear?
;
; #########################################################################

    ; EU MUDEI ISSO ANTES TAVA .386 E AGORA FICOU .586 PRA PODER GERAR NUMEROS ALEATORIOS
    ; SE COMEÇAR A DAR RUIM VOLTAR PARA .386
      .586
      .model flat, stdcall
      option casemap :none

; #########################################################################

      include C:\masm32\include\windows.inc

      include C:\masm32\include\user32.inc
      include C:\masm32\include\kernel32.inc
      include C:\masm32\include\gdi32.inc

      includelib C:\masm32\lib\user32.lib
      includelib C:\masm32\lib\kernel32.lib
      includelib C:\masm32\lib\gdi32.lib
      includelib C:\masm32\lib\

; #########################################################################

      szText MACRO Name, Text:VARARG
        LOCAL lbl
          jmp lbl
            Name db Text,0
          lbl:
        ENDM

      m2m MACRO M1, M2
        push M2
        pop  M1
      ENDM

      return MACRO arg
        mov eax, arg
        ret
      ENDM

; #########################################################################

        WinMain PROTO :DWORD,:DWORD,:DWORD,:DWORD
        WndProc PROTO :DWORD,:DWORD,:DWORD,:DWORD
        TopXY  PROTO  :DWORD,:DWORD
        Random PROTO  :DWORD
        RandomizarFruta PROTO

; #########################################################################
    
    .const
        WM_FINISH     equ WM_USER+100h
        
        ; Códigos dos bitmaps do jogo
        BMP_BG        equ 100 
        BMP_SNAKE     equ 101 
        BMP_FRUIT     equ 102 

        ; Tamanho da área de jogo
        BOARD_HEIGHT  equ 25
        BOARD_WIDTH   equ 25
        BOARD_COUNT   equ BOARD_HEIGHT * BOARD_WIDTH

        ; Tamanho do tile
        TILE_SIZE     equ 20

    .data
        ; Variáveis de configuração
        szDisplayName db "Snake",0
        CommandLine   dd 0
        hWnd          dd 0
        hInstance     dd 0

        ; Variáveis para números aleatórios
        prng_x        dd 0
        prng_a        dd 100711433

        ; Coordenadas da cobra
        snakeX        dd BOARD_COUNT dup(-1)
        snakeY        dd BOARD_COUNT dup(-1)

        livres        dd BOARD_COUNT dup(-1)

    .data?
        ; Coordenadas da fruta
        fruitX        dd ?  
        fruitY        dd ?  

        ; Direção e tamanho da cobra
        direction     dd ?
        snakeSize     dd ?
        
        ; Handle dos bitmaps
        hBmpSnake     dd ?
        hBmpBg        dd ?
        hBmpFruit     dd ?

        ; Handle compativel para desenhar na tela
        hCompatibleDC dd ?
 
        ; Threads
        ThreadID      DWORD  ?
        hEventStart   HANDLE ?

        

; #########################################################################

.code

    start:
        invoke GetModuleHandle, NULL
        mov hInstance, eax

        invoke GetCommandLine
        mov CommandLine, eax

        invoke WinMain, hInstance, NULL, CommandLine, SW_SHOWDEFAULT
        
        invoke ExitProcess, eax

; #########################################################################

WinMain proc hInst:DWORD, hPrevInst:DWORD, CmdLine:DWORD, CmdShow:DWORD

    LOCAL wc:WNDCLASSEX
    LOCAL msg:MSG

    LOCAL Wwd:DWORD
    LOCAL Wht:DWORD
    LOCAL Wtx:DWORD
    LOCAL Wty:DWORD

    szText szClassName, "Generic_Class"

    mov wc.cbSize, sizeof WNDCLASSEX
    mov wc.style, CS_HREDRAW or CS_VREDRAW or CS_BYTEALIGNWINDOW
    mov wc.lpfnWndProc, offset WndProc
    mov wc.cbClsExtra, NULL
    mov wc.cbWndExtra, NULL
    m2m wc.hInstance, hInst
    mov wc.hbrBackground, COLOR_BTNFACE+1 
    mov wc.lpszMenuName, NULL
    mov wc.lpszClassName, offset szClassName
    invoke LoadIcon, hInst, 500
    mov wc.hIcon, eax
    invoke LoadCursor, NULL, IDC_ARROW
    mov wc.hCursor, eax
    mov wc.hIconSm, 0

    invoke RegisterClassEx, ADDR wc

    ; Ajusta o tamanho da janela
    mov Wwd, TILE_SIZE * BOARD_WIDTH + 10
    mov Wht, TILE_SIZE * BOARD_HEIGHT + 32

    ; Largura da tela em pixels
    invoke GetSystemMetrics, SM_CXSCREEN
    invoke TopXY, Wwd, eax
    mov Wtx, eax

    ; Altura da tela em pixels
    invoke GetSystemMetrics, SM_CYSCREEN
    invoke TopXY, Wht, eax
    mov Wty, eax

    ; Cria a janela
    invoke CreateWindowEx, WS_EX_OVERLAPPEDWINDOW,
                            ADDR szClassName,
                            ADDR szDisplayName,
                            WS_SYSMENU,
                            Wtx, Wty, Wwd, Wht,
                            NULL, NULL,
                            hInst, NULL
                            
    mov hWnd, eax

    invoke ShowWindow, hWnd, SW_SHOWNORMAL
    invoke UpdateWindow, hWnd

    StartLoop:
        invoke GetMessage, ADDR msg, NULL, 0, 0
        cmp eax, 0
        je ExitLoop
        invoke TranslateMessage, ADDR msg
        invoke DispatchMessage, ADDR msg
        jmp StartLoop
    ExitLoop:

    return msg.wParam

WinMain endp

; #########################################################################

WndProc proc hWin:DWORD, uMsg:DWORD, wParam:DWORD, lParam:DWORD

LOCAL hDC:DWORD
LOCAL Ps:PAINTSTRUCT
LOCAL i:DWORD
LOCAL j:DWORD

    .if uMsg == WM_CREATE
        invoke Random, BOARD_WIDTH
        mov snakeX[0], eax

        invoke Random, BOARD_HEIGHT
        mov snakeY[0], eax

        mov snakeSize, 1

        invoke RandomizarFruta

        invoke Random, 4
        mov direction, eax

        
        invoke CreateEvent, NULL, FALSE, FALSE, NULL
        mov    hEventStart, eax

        invoke LoadBitmap, hInstance, BMP_BG
        mov    hBmpBg, eax
        
        invoke LoadBitmap, hInstance, BMP_SNAKE
        mov    hBmpSnake, eax
        
        invoke LoadBitmap, hInstance, BMP_FRUIT
        mov    hBmpFruit, eax

        mov    eax, OFFSET ThreadProc
		invoke CreateThread, NULL, NULL, eax, NULL, NORMAL_PRIORITY_CLASS, ADDR ThreadID

    .elseif uMsg == WM_DESTROY

        invoke DeleteObject, hBmpBg
        invoke DeleteObject, hBmpFruit
        invoke DeleteObject, hBmpSnake

        invoke PostQuitMessage,NULL
        return 0 

    .elseif uMsg == WM_KEYDOWN
        .if wParam == VK_UP
            mov direction, 0
        .elseif wParam == VK_RIGHT
            mov direction, 1
        .elseif wParam == VK_DOWN
            mov direction, 2
        .elseif wParam == VK_LEFT
            mov direction, 3
        .elseif wParam == 87
            mov direction, 0
        .elseif wParam == 68
            mov direction, 1
        .elseif wParam == 83
            mov direction, 2
        .elseif wParam == 65
            mov direction, 3
        .endif

    .elseif uMsg == WM_KEYUP

        ; .if wParam == VK_RIGHT
        ;   invoke  InvalidateRect, hWnd, NULL, TRUE
        ; .endif

    .elseif uMsg == WM_FINISH

        invoke  InvalidateRect, hWnd, NULL, TRUE

    .elseif uMsg == WM_PAINT

        invoke BeginPaint, hWin, ADDR Ps
        mov    hDC, eax
        
        invoke CreateCompatibleDC, hDC
        mov    hCompatibleDC, eax


        ; Desenha o background
        invoke SelectObject, hCompatibleDC, hBmpBg
        ; mov i, 0
        ; .while i < BOARD_HEIGHT
        ;     mov j, 0
        ;     .while j < BOARD_WIDTH
        ;         mov  ebx, i
        ;         imul ebx, TILE_SIZE
        ;         mov  ecx, j
        ;         imul ecx, TILE_SIZE
                mov ebx, BOARD_WIDTH
                imul ebx, TILE_SIZE
                mov ecx, BOARD_HEIGHT
                imul ecx, TILE_SIZE
                invoke BitBlt, hDC, ebx, ecx, TILE_SIZE, TILE_SIZE, hCompatibleDC, 0, 0, SRCCOPY
                
        ;         add j, 1
        ;     .endw
        ;     add i, 1
        ; .endw

        ; Desenha a fruta
        invoke SelectObject, hCompatibleDC, hBmpFruit
        mov  ebx, fruitX
        imul ebx, TILE_SIZE
        mov  ecx, fruitY
        imul ecx, TILE_SIZE
        invoke BitBlt, hDC, ebx, ecx, TILE_SIZE, TILE_SIZE, hCompatibleDC, 0, 0, SRCCOPY

        ; Desenha a cobra
        invoke SelectObject, hCompatibleDC, hBmpSnake
        mov edi, 0
        forI:
            mov ebx, snakeX[4 * edi]

            cmp ebx, -1
            je endForI

            mov ebx, snakeX[4 * edi]
            imul ebx, TILE_SIZE

            mov  ecx, snakeY[4 * edi]
            imul ecx, TILE_SIZE

            invoke BitBlt, hDC, ebx, ecx, TILE_SIZE, TILE_SIZE, hCompatibleDC, 0, 0, SRCCOPY
            
            inc edi
            jmp forI
        endForI:

        invoke DeleteDC, hCompatibleDC

        invoke EndPaint, hWin, ADDR Ps
        return 0
    .endif

    invoke DefWindowProc,hWin,uMsg,wParam,lParam

    ret

WndProc endp

; ########################################################################

TopXY proc wDim:DWORD, sDim:DWORD
    shr sDim, 1
    shr wDim, 1
    mov eax, wDim
    sub sDim, eax

    return sDim

TopXY endp

; ########################################################################

; Thread para tick do jogo
ThreadProc PROC USES ecx Param:DWORD
LOCAL i:DWORD

    invoke WaitForSingleObject, hEventStart, 100
    .if eax == WAIT_TIMEOUT

        mov esi, snakeSize
        dec esi
        
        ; Passa os tiles da cobra pra frente
        loopSnake:
            mov ebx, snakeX[4 * esi]
            mov snakeX[4 * esi + 4], ebx

            mov ebx, snakeY[4 * esi]
            mov snakeY[4 * esi + 4], ebx

            
            .if esi == 0
                jmp saindodaqui
            .endif

            dec esi
            jmp loopSnake
        saindodaqui:

        ; Altera o valor da cabeça da cobra de acordo com a direção
        .if direction == 0
            dec snakeY[0]
        .elseif direction == 1
            inc snakeX[0]
        .elseif direction == 2
            inc snakeY[0]
        .elseif direction == 3
            dec snakeX[0]
        .endif

        ; Verifica se a cobra comeu a fruta
        mov eax, fruitX
        mov ebx, fruitY
        .if eax == snakeX && ebx == snakeY
            invoke RandomizarFruta
            inc snakeSize
        .endif

        ; Deleta o último quadrado (só se a cobra não tiver comido a fruta)
        mov ebx, snakeSize
        mov snakeX[4 * ebx], -1
        mov snakeY[4 * ebx], -1

        invoke  SendMessage, hWnd, WM_FINISH, NULL, NULL
    .endif
    
    jmp   ThreadProc
    ret
ThreadProc endp

; ########################################################################

RandomizarFruta proc
LOCAL ultimo:DWORD

    mov esi, 0
    mov ultimo, 0
    
    .while esi < BOARD_COUNT
        mov edi, 0

        .while edi < snakeSize
            ; Transforma X e Y em um número só
            mov eax, snakeY[4 * edi]
            imul eax, BOARD_WIDTH
            add eax, snakeX[4 * edi]

            ; Se o tile i está ocupado por uma cobra
            .if esi == eax
                jmp temCobra
            .endif

            inc edi
        .endw

        mov edx, esi
        mov ecx, ultimo
        mov livres[4 * ecx], edx
        inc ultimo

    temCobra:
        inc esi

    .endw

    dec ultimo
    invoke Random, ultimo

    mov eax, livres[4 * eax]
    mov ebx, BOARD_WIDTH
    mov edx, 0
    div ebx

    mov fruitX, edx
    mov fruitY, eax

    ret

RandomizarFruta endp

; ########################################################################

; Procedure para números aleatórios
Random proc range:DWORD   
    rdtsc
    adc eax, edx
    adc eax, prng_x
    mul prng_a
    adc eax, edx
    mov prng_x, eax
    mul range
    mov eax, edx
    ret
Random endp

; ########################################################################

end start