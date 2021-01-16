# file      BootLoader.asm
# date      2008/11/27
# author    kkamagui 
#           Copyright(c)2008 All rights reserved by kkamagui
# brief     MINT64 OS의 부트 로더 소스 파일

[ORG 0x00]          ; 코드의 시작 어드레스를 0x00으로 설정
[BITS 16]           ; 이하의 코드는 16비트 코드로 설정

SECTION .text       ; text 섹션(세그먼트)을 정의

jmp 0x07C0:START    ; CS 세그먼트 레지스터에 0x07C0을 복사하면서, START 레이블로 이동

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;   MINT64 OS에 관련된 환경 설정 값
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
TOTALSECTORCOUNT:   dw  0x02    ; 부트 로더를 제외한 MINT64 OS 이미지의 크기
                                ; 최대 1146 섹터(0x8F400byte)까지 가능
KERNEL32SECTORCOUNT: dw 0x02    ; 보호 모드 커널의 총 섹터 수
BOOTSTRAPPROCESSOR: db 0x01     ; Bootstrap Processor인지 여부
STARTGRAPHICMODE:   db 0x01     ; 그래픽 모드로 시작하는지 여부

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;   코드 영역
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
START:
    mov ax, 0x07C0  ; 부트 로더의 시작 어드레스(0x7C00)를 세그먼트 레지스터 값(0x07C0)으로 변환
    mov ds, ax      ; DS 세그먼트 레지스터에 설정
    mov ax, 0xB800  ; 비디오 메모리의 시작 어드레스(0xB800)를 세그먼트 레지스터 값(0xB800)으로 변환
    mov es, ax      ; ES 세그먼트 레지스터에 설정

    ; 스택을 0x0000:0000~0x0000:FFFF 영역에 64KB 크기로 생성
    mov ax, 0x0000  ; 스택 세그먼트의 시작 어드레스(0x0000)를 세그먼트 레지스터 값으로 변환
    mov ss, ax      ; SS 세그먼트 레지스터에 설정
    mov sp, 0xFFFE  ; SP 레지스터의 어드레스를 0xFFFE로 설정
    mov bp, 0xFFFE  ; BP 레지스터의 어드레스를 0xFFFE로 설정

    mov byte[ BOOTDRIVE ], dl       ; 부팅한 드라이브의 번호를 메모리에 저장

    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    ; 화면을 모두 지우고, 속성값을 녹색으로 설정
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    mov si,    0                    ; SI 레지스터(문자열 원본 인덱스 레지스터)를 초기화
    
.SCREENCLEARLOOP:                   ; 화면을 지우는 루프
    mov byte [ es: si ], 0          ; 비디오 메모리의 문자가 위치하는 어드레스에
                                    ; 0을 복사하여 문자를 삭제
    mov byte [ es: si + 1 ], 0x0A   ; 비디오 메모리의 속성이 위치하는 어드레스에
                                    ; 0x0A(검은 바탕에 밝은 녹색)을 복사


    add si, 2                       ; 문자와 속성을 설정했으므로 다음 위치로 이동

    cmp si, 80 * 25 * 2     ; 화면의 전체 크기는 80 문자 * 25 라인임
                            ; 출력한 문자의 수를 의미하는 SI 레지스터와 비교
    jl .SCREENCLEARLOOP     ; SI 레지스터가 80 * 25 * 2보다 작다면 아직 지우지 
                            ; 못한 영역이 있으므로 .SCREENCLEARLOOP 레이블로 이동
    
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    ; 화면 상단에 시작 메시지를 출력
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    push MESSAGE1               ; 출력할 메시지의 어드레스를 스택에 삽입
    push 0                      ; 화면 Y 좌표(0)를 스택에 삽입
    push 0                      ; 화면 X 좌표(0)를 스택에 삽입
    call PRINTMESSAGE           ; PRINTMESSAGE 함수 호출
    add  sp, 6                  ; 삽입한 파라미터 제거
    
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    ; OS 이미지를 로딩한다는 메시지 출력
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    push IMAGELOADINGMESSAGE    ; 출력할 메시지의 어드레스를 스택에 삽입           
    push 1                      ; 화면 Y 좌표(1)를 스택에 삽입                     
    push 0                      ; 화면 X 좌표(0)를 스택에 삽입                     
    call PRINTMESSAGE           ; PRINTMESSAGE 함수 호출                           
    add  sp, 6                  ; 삽입한 파라미터 제거                             
        
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    ; 디스크에서 OS 이미지를 로딩
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    ; 디스크를 읽기 전에 먼저 리셋
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
RESETDISK:                          ; 디스크를 리셋하는 코드의 시작
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    ; BIOS Reset Function 호출
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    mov ax, 0                           ; BIOS 서비스 번호 0(Reset Disk Drives)
    mov dl, byte [ BOOTDRIVE ]          ; 부팅 드라이브를 타겟으로 설정
    int 0x13     
    ; 에러가 발생하면 에러 처리로 이동
    jc  HANDLEDISKERROR

    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    ; 디스크 파라미터를 읽음
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    mov     ah, 0x08                    ; BIOS 서비스 번호 8(Read Disk Parameters)
    mov     dl, byte [ BOOTDRIVE ]      ; 부팅 드라이브를 타겟으로 설정
    int     0x13                        ; 인터럽트 서비스 수행
    jc      HANDLEDISKERROR             ; 에러가 발생했다면 HANDLEDISKERROR로 이동

    mov     byte [ LASTHEAD ], dh       ; 헤드 정보를 메모리에 저장
    mov     al, cl                      ; 섹터와 트랙 정보를 AL 레지스터에 저장
    and     al, 0x3f                    ; 섹터 정보(하위 6 비트)를 추출하여
                                        ; AL 레지스터에 저장
    mov     byte [ LASTSECTOR ], al     ; 섹터 정보를 메모리에 저장
    mov     byte [ LASTTRACK ], ch      ; 트랙 정보 중에서 하위 8 비트를 메모리에 저장
        
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    ; 디스크에서 섹터를 읽음
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    ; 디스크의 내용을 메모리로 복사할 어드레스(ES:BX)를 0x10000으로 설정
    mov si, 0x1000                  ; OS 이미지를 복사할 어드레스(0x10000)를 
                                    ; 세그먼트 레지스터 값으로 변환
    mov es, si                      ; ES 세그먼트 레지스터에 값 설정
    mov bx, 0x0000                  ; BX 레지스터에 0x0000을 설정하여 복사할 
                                    ; 어드레스를 0x1000:0000(0x10000)으로 최종 설정
        
    ;mov di, word [ TOTALSECTORCOUNT ] ; 복사할 OS 이미지의 섹터 수를 DI 레지스터에 설정
    mov di, 1146                    ; OS 이미지 뒤에 있는 패키지 파일을 로딩하려고
                                    ; 573Kbyte(1146 섹터)까지 읽도록 개수를 설정
        
READDATA:                           ; 디스크를 읽는 코드의 시작
    ; 모든 섹터를 다 읽었는지 확인
    cmp di, 0               ; 복사할 OS 이미지의 섹터 수를 0과 비교
    je  READEND             ; 복사할 섹터 수가 0이라면 다 복사 했으므로 READEND로 이동
    sub di, 0x1             ; 복사할 섹터 수를 1 감소

    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    ; BIOS Read Function 호출
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    mov ah, 0x02                        ; BIOS 서비스 번호 2(Read Sector)
    mov al, 0x1                         ; 읽을 섹터 수는 1
    mov ch, byte [ TRACKNUMBER ]        ; 읽을 트랙 번호 설정
    mov cl, byte [ SECTORNUMBER ]       ; 읽을 섹터 번호 설정
    mov dh, byte [ HEADNUMBER ]         ; 읽을 헤드 번호 설정
    mov dl, byte [ BOOTDRIVE ]          ; 부팅 드라이브를 타겟으로 설정
    int 0x13                            ; 인터럽트 서비스 수행
    jc HANDLEDISKERROR                  ; 에러가 발생했다면 HANDLEDISKERROR로 이동
    
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    ; 복사할 어드레스와 트랙, 헤드, 섹터 어드레스 계산
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    add si, 0x0020      ; 512(0x200)바이트만큼 읽었으므로, 이를 세그먼트 레지스터
                        ; 값으로 변환
    mov es, si          ; ES 세그먼트 레지스터에 더해서 어드레스를 한 섹터 만큼 증가
    
    ; 한 섹터를 읽었으므로 섹터 번호를 증가시키고 마지막 섹터(18)까지 읽었는지 판단
    ; 마지막 섹터가 아니면 섹터 읽기로 이동해서 다시 섹터 읽기 수행
    mov al, byte [ SECTORNUMBER ]       ; 섹터 번호를 AL 레지스터에 설정
    add al, 0x01                        ; 섹터 번호를 1 증가
    mov byte [ SECTORNUMBER ], al       ; 증가시킨 섹터 번호를 SECTORNUMBER에 다시 설정
    cmp al, byte [ LASTSECTOR ]         ; 증가시킨 섹터 번호를 마지막 섹터 번호와 비교
    jle READDATA                        ; 섹터 번호가 마지막 섹터 이하라면 READDATA로 이동
    
    ; 마지막 섹터까지 읽었으면 헤드를 증가시키고, 섹터 번호를 1로 설정
    add byte [ HEADNUMBER ], 0x01       ; 헤드 번호를 1 증가
    mov byte [ SECTORNUMBER ], 0x01     ; 섹터 번호를 다시 1로 설정
    
    ; 만약 헤드를 모두 읽었으면 트랙 번호를 1 증가
    mov al, byte [ LASTHEAD ]           ; 마지막 헤드 번호를 AL 레지스터에 설정
    cmp byte [ HEADNUMBER ], al         ; 헤드 번호를 마지막 헤드 번호와 비교하고
    jg .ADDTRACK                        ; 마지막 헤드 번호보다 크면 트랙 번호를 1 증가

    jmp READDATA

.ADDTRACK:
    ; 트랙을 1 증가시킨 후, 다시 섹터 읽기로 이동
    mov byte [ HEADNUMBER ], 0x00       ; 헤드 번호를 0으로 설정
    add byte [ TRACKNUMBER ], 0x01      ; 트랙 번호를 1 증가
    jmp READDATA                        ; READDATA로 이동

READEND:

    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    ; OS 이미지가 완료되었다는 메시지를 출력
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    push LOADINGCOMPLETEMESSAGE     ; 출력할 메시지의 어드레스를 스택에 삽입
    push 1                          ; 화면 Y 좌표(1)를 스택에 삽입
    push 20                         ; 화면 X 좌표(20)를 스택에 삽입
    call PRINTMESSAGE               ; PRINTMESSAGE 함수 호출
    add  sp, 6                      ; 삽입한 파라미터 제거

    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    ; VBE 기능 번호 0x4F01을 호출하여 그래픽 모드에 대한 모드 정보 블록을 구함  
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    mov ax, 0x4F01      ; VBE 기능 번호 0x4F01를 AX 레지스터에 저장
    mov cx, 0x117       ; 1024x768 해상도에 16비트(R(5):G(6):B(5)) 색 모드 지정
    mov bx, 0x07E0      ; BX 레지스터에 0x07E0를 저장
    mov es, bx          ; ES 세그먼트 레지스터에 BX의 값을 설정하고, DI 레지스터에 
    mov di, 0x00        ; 0x00을 설정하여 0x07E0:0000(0x7E00) 어드레스에 모드 정보
                        ; 블록을 저장
    int 0x10            ; 인터럽트 서비스 수행
    cmp ax, 0x004F      ; 에러가 발생했다면 VBEERROR로 이동
    jne VBEERROR    

    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    ; VBE 기능 번호 0x4F02을 호출하여 그래픽 모드로 전환 
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    ; 부트 로더의 그래픽 모드 전환 플래그를 확인하여 1일 때만 그래픽 모드로 전환
    cmp byte [ STARTGRAPHICMODE ], 0x00     ; 그래픽 모드 시작하는지 여부를 0x00과 비교
    je JUMPTOPROTECTEDMODE                  ; 0x00과 같다면 바로 보호 모드로 전환
    
    mov ax, 0x4F02      ; VBE 기능 번호 0x4F02를 AX 레지스터에 저장
    mov bx, 0x4117      ; 1024x768 해상도에 16비트(R(5):G(6):B(5)) 색을 사용하는 
                        ; 선형 프레임 버퍼 모드 지정
                        ; VBE 모드 번호(Bit 0~8) = 0x117, 
                        ; 버퍼 모드(비트 14) = 1(선형 프레임 버퍼 모드)
    int 0x10            ; 인터럽트 서비스 수행
    cmp ax, 0x004F      ; 에러가 발생했다면 VBEERROR로 이동
    jne VBEERROR    
    
    ; 그래픽 모드로 전환되었다면 보호 모드 커널로 이동
    jmp JUMPTOPROTECTEDMODE

VBEERROR:
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    ;... 예외 처리 ...
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    ; 그래픽 모드 전환이 실패했다는 메시지를 출력
    push CHANGEGRAPHICMODEFAIL
    push 2
    push 0
    call PRINTMESSAGE
    add  sp, 6    
    jmp $

JUMPTOPROTECTEDMODE:
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    ; 로딩한 가상 OS 이미지 실행    
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    jmp 0x1000:0x0000
    
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;   함수 코드 영역
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; 디스크 에러를 처리하는 함수   
HANDLEDISKERROR:
    push DISKERRORMESSAGE   ; 에러 문자열의 어드레스를 스택에 삽입
    push 1                  ; 화면 Y 좌표(1)를 스택에 삽입
    push 20                 ; 화면 X 좌표(20)를 스택에 삽입
    call PRINTMESSAGE       ; PRINTMESSAGE 함수 호출
    
    jmp $                   ; 현재 위치에서 무한 루프 수행

; 메시지를 출력하는 함수
;   PARAM: x 좌표, y 좌표, 문자열
PRINTMESSAGE:
    push bp         ; 베이스 포인터 레지스터(BP)를 스택에 삽입
    mov bp, sp      ; 베이스 포인터 레지스터(BP)에 스택 포인터 레지스터(SP)의 값을 설정
                    ; 베이스 포인터 레지스터(BP)를 이용해서 파라미터에 접근할 목적

    push es         ; ES 세그먼트 레지스터부터 DX 레지스터까지 스택에 삽입
    push si         ; 함수에서 임시로 사용하는 레지스터로 함수의 마지막 부분에서
    push di         ; 스택에 삽입된 값을 꺼내 원래 값으로 복원
    push ax
    push cx
    push dx
    
    ; ES 세그먼트 레지스터에 비디오 모드 어드레스 설정
    mov ax, 0xB800              ; 비디오 메모리 시작 어드레스(0x0B8000)를 
                                ; 세그먼트 레지스터 값으로 변환
    mov es, ax                  ; ES 세그먼트 레지스터에 설정
    
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    ; X, Y의 좌표로 비디오 메모리의 어드레스를 계산함
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    ; Y 좌표를 이용해서 먼저 라인 어드레스를 구함
    mov ax, word [ bp + 6 ]     ; 파라미터 2(화면 좌표 Y)를 AX 레지스터에 설정
    mov si, 160                 ; 한 라인의 바이트 수(2 * 80 컬럼)를 SI 레지스터에 설정
    mul si                      ; AX 레지스터와 SI 레지스터를 곱하여 화면 Y 어드레스 계산
    mov di, ax                  ; 계산된 화면 Y 어드레스를 DI 레지스터에 설정
    
    ; X 좌료를 이용해서 2를 곱한 후 최종 어드레스를 구함
    mov ax, word [ bp + 4 ]     ; 파라미터 1(화면 좌표 X)를 AX 레지스터에 설정
    mov si, 2                   ; 한 문자를 나타내는 바이트 수(2)를 SI 레지스터에 설정
    mul si                      ; AX 레지스터와 SI 레지스터를 곱하여 화면 X 어드레스를 계산
    add di, ax                  ; 화면 Y 어드레스와 계산된 X 어드레스를 더해서
                                ; 실제 비디오 메모리 어드레스를 계산
    
    ; 출력할 문자열의 어드레스      
    mov si, word [ bp + 8 ]     ; 파라미터 3(출력할 문자열의 어드레스)
    
.MESSAGELOOP:               ; 메시지를 출력하는 루프
    mov cl, byte [ si ]     ; SI 레지스터가 가리키는 문자열 위치에서 한 문자를 
                            ; CL 레지스터에 복사
                            ; CL 레지스터는 CX 레지스터의 하위 1바이트를 의미
                            ; 문자열은 1바이트면 충분하므로 CX 레지스터의 하위 1바이트만 사용

    cmp cl, 0               ; 복사된 문자와 0을 비교
    je .MESSAGEEND          ; 복사한 문자의 값이 0이면 문자열이 종료되었음을
                            ; 의미하므로 .MESSAGEEND로 이동하여 문자 출력 종료

    mov byte [ es: di ], cl ; 0이 아니라면 비디오 메모리 어드레스 0xB800:di에 문자를 출력

    add si, 1               ; SI 레지스터에 1을 더하여 다음 문자열로 이동
    add di, 2               ; DI 레지스터에 2를 더하여 비디오 메모리의 다음 문자 위치로 이동
                            ; 비디오 메모리는 (문자, 속성)의 쌍으로 구성되므로 문자만 출력하려면
                            ; 2를 더해야 함

    jmp .MESSAGELOOP        ; 메시지 출력 루프로 이동하여 다음 문자를 출력
    
.MESSAGEEND:
    pop dx      ; 함수에서 사용이 끝난 DX 레지스터부터 ES 레지스터까지를 스택에
    pop cx      ; 삽입된 값을 이용해서 복원
    pop ax      ; 스택은 가장 마지막에 들어간 데이터가 가장 먼저 나오는 
    pop di      ; 자료구조(Last-In, First-Out)이므로 삽입(push)의 역순으로
    pop si      ; 제거(pop) 해야 함
    pop es
    pop bp      ; 베이스 포인터 레지스터(BP) 복원
    ret         ; 함수를 호출한 다음 코드의 위치로 복귀
    
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;   데이터 영역
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; 부트 로더 시작 메시지는 심각한 오류를 나타내는 메시지를 제외하고 모두 삭제
MESSAGE1:               db  0
DISKERRORMESSAGE:       db  'DISK Error~!!', 0
IMAGELOADINGMESSAGE:    db  0
LOADINGCOMPLETEMESSAGE: db  0
CHANGEGRAPHICMODEFAIL:  db  0
;MESSAGE1:    db 'MINT64 OS Boot Loader Start~!!', 0 ; 출력할 메시지 정의
                                    ; 마지막은 0으로 설정하여 .MESSAGELOOP에서 
                                    ; 문자열이 종료되었음을 알 수 있도록 함
;DISKERRORMESSAGE:       db  'DISK Error~!!', 0
;IMAGELOADINGMESSAGE:    db  'OS Image Loading...', 0
;LOADINGCOMPLETEMESSAGE: db  'Complete~!!', 0
;CHANGEGRAPHICMODEFAIL:  db  'Change Graphic Mode Fail~!!', 0

; 디스크 읽기에 관련된 변수들
SECTORNUMBER:           db  0x02    ; OS 이미지가 시작하는 섹터 번호를 저장하는 영역
HEADNUMBER:             db  0x00    ; OS 이미지가 시작하는 헤드 번호를 저장하는 영역
TRACKNUMBER:            db  0x00    ; OS 이미지가 시작하는 트랙 번호를 저장하는 영역

; 디스크 파라미터에 관련된 변수들
BOOTDRIVE:              db 0x00     ; 부팅한 드라이브의 번호를 저장하는 영역
LASTSECTOR:             db 0x00     ; 드라이브의 마지막 섹터 번호 -1을 저장하는 영역
LASTHEAD:               db 0x00     ; 드라이브의 마지막 헤드 번호를 저장하는 영역
LASTTRACK:              db 0x00     ; 드라이브의 마지막 트랙 번호를 저장하는 영역
    
times 510 - ( $ - $$ )    db    0x00    ; $ : 현재 라인의 어드레스
                                        ; $$ : 현재 섹션(.text)의 시작 어드레스
                                        ; $ - $$ : 현재 섹션을 기준으로 하는 오프셋
                                        ; 510 - ( $ - $$ ) : 현재부터 어드레스 510까지
                                        ; db 0x00 : 1바이트를 선언하고 값은 0x00
                                        ; time : 반복 수행
                                        ; 현재 위치에서 어드레스 510까지 0x00으로 채움

db 0x55             ; 1바이트를 선언하고 값은 0x55
db 0xAA             ; 1바이트를 선언하고 값은 0xAA
                    ; 어드레스 511, 512에 0x55, 0xAA를 써서 부트 섹터로 표기함
