*-------------------------------------------------------------
* Macros, call numbers, direct page and layout
*-------------------------------------------------------------
Tool        MAC
            ldx   #]1
            jsl   $E10000
            <<<

GSOS        MAC
            jsl   $E100A8
            da    ]1
            adrl  ]2
            <<<

PushLong    MAC
            pea   ^]1
            pea   ]1
            <<<

* a long stored at a label
PushLongAt  MAC
            lda   ]1+2
            pha
            lda   ]1
            pha
            <<<

* Tool Locator, Memory Manager, Miscellaneous Tools
_TLStartUp  equ   $0201
_TLShutDown equ   $0301
_StartUpTools equ $1801
_ShutDownTools equ $1901
_MMStartUp  equ   $0202
_MMShutDown equ   $0302
_NewHandle  equ   $0902
_DisposeHandle equ $1002
_SysBeep    equ   $2C03
* QuickDraw II and QuickDraw II Auxiliary
_SetPort    equ   $1B04
_SetPenSize equ   $2C04
_SetSolidPenPat equ $3704
_MoveTo     equ   $3A04
_FrameRect  equ   $5304
_PaintRect  equ   $5404
_GetMouse   equ   $0C06
_Button     equ   $0D06
_EraseRect  equ   $5504
_GlobalToLocal equ $8504
_SetForeColor equ $A004
_SetBackColor equ $A204
_DrawCString equ  $A604
_CStringWidth equ $AA04
_InitCursor equ   $CA04
_DrawIcon   equ   $0B12
_WaitCursor equ   $0A12
* Desk Manager, Event Manager
_FixAppleMenu equ $1E05
_GetNextEvent equ $0A06
_FlushEvents equ  $1506
* Control Manager
_NewControl equ   $0910
_KillControls equ $0B10
_DrawControls equ $1010
_FindControl equ  $1310
_TrackControl equ $1510
* Window Manager
_NewWindow  equ   $090E
_CloseWindow equ  $0B0E
_SetWTitle  equ   $0D0E
_MoveWindow equ   $190E
_SizeWindow equ   $1C0E
_TaskMaster equ   $1D0E
_InvalRect  equ   $3A0E
_AlertWindow equ  $590E
* Menu Manager
_InsertMenu equ   $0D0F
_FixMenuBar equ   $130F
_DrawMenuBar equ  $2A0F
_HiliteMenu equ   $2C0F
_NewMenu    equ   $2D0F
_CheckMItem equ   $320F
* Standard File
_SFGetFile2 equ   $0E17

* GS/OS (class 1)
_CreateGS   equ   $2001
_DestroyGS  equ   $2002
_GetFileInfoGS equ $2006
_OpenGS     equ   $2010
_ReadGS     equ   $2012
_WriteGS    equ   $2013
_CloseGS    equ   $2014
_GetEOFGS   equ   $2019
_GetDirEntryGS equ $201C
_DInfoGS    equ   $202C
_DStatusGS  equ   $202D
_VolumeGS   equ   $2008
_QuitGS     equ   $2029
_OSShutdownGS equ $2003
_GetBootVolGS equ $2028
_SetPrefixGS equ  $2009

* TaskMaster results and event codes
evKeyDown   equ   3
evAutoKey   equ   5
wInMenuBar  equ   $11
wInContent  equ   $13
wInSpecial  equ   $19
TaskData    equ   16                ; (offsets in EventRec)

* keys
K_LEFT      equ   $08
K_RIGHT     equ   $15
K_RETURN    equ   $0D
K_ESC       equ   $1B
K_TAB       equ   $09
K_UP        equ   $0B
K_DOWN      equ   $0A
K_DEL       equ   $7F

* file types that can be launched
tS16        equ   $B3
tSYS        equ   $FF
tICN        equ   $CA

* the slots
MaxSlots    equ   18
PathMax     equ   254               ; (a slot's path: a GS/OS string)
PathSz      equ   260               ; bytes a slot's path takes
NameMax     equ   31                ; (a slot's name: a C string)
NameSz      equ   32
DateSz      equ   16
IconMax     equ   768               ; (a slot's icon record, at most)
MasterMax   equ   7000              ; (the slots file, at most)
LineMax     equ   300

* the window: cells of CellW x CellH, 3 to 5 a row
CellW       equ   120
CellH       equ   52
Margin      equ   6
MinCols     equ   3
MaxCols     equ   5
WinTop      equ   40                ; (its content's top on the screen)

* direct page (ours, from the loader)
IPtr        equ   $00               ; long: the icon file buffer (64K)
Ptr         equ   $04               ; long: general
SP1         equ   $08               ; words: pointers in this bank
SP2         equ   $0A
T0          equ   $10
T1          equ   $12
T2          equ   $14
T3          equ   $16
T4          equ   $18
T5          equ   $1A
T6          equ   $1C
T7          equ   $1E
PX          equ   $20
PY          equ   $22
OPtr        equ   $0C               ; word: where BuildLine writes

* the Find Apps window (local coordinates)
MaxFound    equ   100
MaxVols     equ   16
MaxDepth    equ   7
RowsOnb     equ   8
OListTop    equ   36
OInfoY      equ   144
OBtnTop     equ   150

* pages (tabs)
MaxGroups   equ   4
TabH        equ   18
TabW        equ   90

* the scroll bar beside the list (local coordinates)
SbL         equ   542
SbR         equ   556
SbCx        equ   549
SbT         equ   36
SbB         equ   132
ArrowH      equ   14
TrackH      equ   68
