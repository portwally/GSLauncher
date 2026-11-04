*-------------------------------------------------------------
* GSLauncher - a program launcher for GS/OS (System 6)
*
* A window of app slots: each shows the app's Finder icon, its name
* and the date of the file. A click launches the app (GS/OS Quit
* with the return flag: quitting the app comes back here). The slots
* are kept in 9:Launcher.Slots, a text file of name=path lines.
*-------------------------------------------------------------
            rel
            mx    %00
            put   equ.s

Start       phk
            plb
            phk                     ; (our bank, for pointers to our data)
            phk
            pla
            and   #$FF
            sta   MyBank
            tdc
            sta   MyDP
            Tool  _TLStartUp
            pha
            Tool  _MMStartUp
            pla
            sta   UserID
            pha                     ; result: start/stop reference
            pha
            lda   UserID
            pha
            pea   0                 ; the record below is a pointer
            PushLong StartStop
            Tool  _StartUpTools
            pla
            sta   SSRef
            pla
            sta   SSRef+2
            bcc   :tools
            jmp   Fatal
:tools      jsr   AllocMem
            bcc   :mem
            jmp   Fatal
:mem        jsr   MakeMenus
            Tool  _InitCursor
            Tool  _WaitCursor       ; (finding the icons takes a moment)
            jsr   LoadSlots
            jsr   ScanAll
            jsr   Layout
            jsr   MakeWindow
            Tool  _InitCursor

*-------------------------------------------------------------
* Main event loop
*-------------------------------------------------------------
EventLoop   pha
            pea   $FFFF
            PushLong EventRec
            Tool  _TaskMaster
            pla
            beq   EventLoop
            cmp   #evKeyDown
            beq   :key
            cmp   #evAutoKey
            beq   :key
            cmp   #wInMenuBar
            beq   :menu
            cmp   #wInSpecial
            beq   :menu
            cmp   #wInContent
            beq   :click
            bra   EventLoop
:key        jsr   DoKey
            bra   EventLoop
:menu       jsr   DoMenu
            bra   EventLoop
:click      jsr   DoClick
            bra   EventLoop

* Keys: in Edit mode the arrows choose a slot, Escape ends Edit mode
DoKey       lda   EditMode
            beq   :x
            lda   EventRec+2
            and   #$7F
            cmp   #K_ESC
            bne   :l
            jmp   EditToggle
:l          cmp   #K_LEFT
            bne   :r
            lda   Sel
            beq   :x
            cmp   NSlots
            bcs   :x
            dec   Sel
            jmp   Redraw
:r          cmp   #K_RIGHT
            bne   :x
            lda   Sel
            inc
            cmp   NSlots
            bcs   :x
            sta   Sel
            jmp   Redraw
:x          rts

* Clicks: launch the slot (in Edit mode: select it)
DoClick     jsr   UsePort
            lda   EventRec+10       ; where (global): v, h
            sta   ClickPt
            lda   EventRec+12
            sta   ClickPt+2
            PushLong ClickPt
            Tool  _GlobalToLocal
            jsr   HitSlot
            bcs   :x
            ldx   EditMode
            bne   :sel
            jmp   Launch
:sel        sta   Sel
            jmp   Redraw
:x          rts

* HitSlot: the slot at ClickPt (local): A = its number, carry clear
HitSlot     lda   ClickPt+2         ; the column
            sec
            sbc   #Margin
            bcc   :no
            ldx   #0
:c          cmp   #CellW
            bcc   :col
            sbc   #CellW
            inx
            bra   :c
:col        cpx   Cols
            bcs   :no
            stx   T0
            lda   ClickPt           ; the row
            sec
            sbc   #Margin
            bcc   :no
            ldx   #0
:r          cmp   #CellH
            bcc   :row
            sbc   #CellH
            inx
            bra   :r
:row        lda   T0                ; row * Cols + column
:m          dex
            bmi   :idx
            clc
            adc   Cols
            bra   :m
:idx        cmp   NSlots
            bcs   :no
            clc
            rts
:no         sec
            rts

*-------------------------------------------------------------
* Launching
*-------------------------------------------------------------
* Launch: A = a slot: its app, coming back here when it quits
Launch      sta   CurI
            jsr   FileInfo          ; (still there? its type)
            lda   CurI
            asl
            tax
            lda   SlotOK,x
            bne   :there
            jsr   Redraw            ; (shown as missing now)
            ldx   #NotFoundA
            jsr   MsgStart
            lda   CurI
            jsr   NameOf
            tax
            jsr   MsgCat
            ldx   #NotFoundB
            jsr   MsgCat
            jmp   MsgAlert
:there      lda   SlotType,x
            cmp   #tS16
            beq   :app
            cmp   #tSYS
            beq   :app
            ldx   #NotAppTx
            jmp   Alert
:app         lda   CurI
            jsr   FullPath          ; ("*" as the boot disk's name: a
            jsr   SetPrefix0        ; (its folder: a ProDOS 8 app's prefix)
            lda   #PathBuf          ; ProDOS 8 app needs a real prefix)
            sta   QuitParms+2
            lda   MyBank
            sta   QuitParms+4
            lda   #$8000            ; back here when it quits
            sta   QuitParms+6
            jmp   QuitTo

* FullPath: A = a slot: PathBuf = its path, a leading "*" made the
* name of the boot disk
FullPath    jsr   PathOf
            tax
            ldy   #PathBuf
            jsr   CopyGS
            lda   PathBuf+2
            and   #$FF
            cmp   #'*'
            bne   :x
            GSOS  _GetBootVolGS;BootParms
            bcs   :x
            ldx   #0                ; VolBuf+4: the name; with ':' first
            lda   VolBuf+4
            and   #$FF
            jsr   IsSep
            beq   :v
            lda   #':'
            sta   FilePath+2
            inx
:v          ldy   #0                ; (FilePath as the work space)
:vc         cpy   VolBuf+2
            bcs   :vd
            lda   VolBuf+4,y
            sep   #$20
            mx    %10
            sta   FilePath+2,x
            rep   #$20
            mx    %00
            inx
            iny
            bra   :vc
:vd         lda   FilePath+1,x      ; (no ':' at its end)
            and   #$FF
            jsr   IsSep
            bne   :r
            dex
:r          ldy   #1                ; then the rest, after the "*"
:rc         cpy   PathBuf
            bcs   :rd
            cpx   #PathMax
            bcs   :x
            lda   PathBuf+2,y
            sep   #$20
            mx    %10
            sta   FilePath+2,x
            rep   #$20
            mx    %00
            inx
            iny
            bra   :rc
:rd         stx   FilePath
            ldx   #FilePath
            ldy   #PathBuf
            jmp   CopyGS
:x          rts

* SetPrefix0: prefix 0 (ProDOS 8's prefix) = PathBuf's folder
SetPrefix0  lda   #PathBuf
            sta   SP1
            jsr   LastSep
            bcs   :x
            sta   T5
            ldy   #0
:c          cpy   T5
            bcs   :d
            lda   PathBuf+2,y
            sep   #$20
            mx    %10
            sta   FilePath+2,y
            rep   #$20
            mx    %00
            iny
            bra   :c
:d          sty   FilePath
            GSOS  _SetPrefixGS;PfxParms
:x          rts

* Quit to the Finder (by name: started at boot, a plain Quit would
* only start the launcher again)
QuitFinder  lda   #FinderPath
            ldx   #GFIParms
            jsr   SetPath
            GSOS  _GetFileInfoGS;GFIParms
            bcc   :ok
            ldx   #NoFinderTx
            jmp   Alert
:ok         lda   #FinderPath
            sta   QuitParms+2
            lda   MyBank
            sta   QuitParms+4
            stz   QuitParms+6
* QuitTo: the tools shut down, then GS/OS Quit with QuitParms
QuitTo      Tool  _WaitCursor
            pea   0
            PushLongAt SSRef
            Tool  _ShutDownTools
            lda   UserID
            pha
            Tool  _MMShutDown
            Tool  _TLShutDown
            GSOS  _QuitGS;QuitParms
            jmp   Start             ; (it could not be started: back again)

Fatal       Tool  _SysBeep
            stz   QuitParms+2
            stz   QuitParms+4
            stz   QuitParms+6
            GSOS  _QuitGS;QuitParms
            brk   $00

*-------------------------------------------------------------
* Menus
*-------------------------------------------------------------
MakeMenus   PushLong EditMenu
            jsr   AddMenu
            PushLong FileMenu
            jsr   AddMenu
            PushLong AppleMenu
            jsr   AddMenu
            pea   1                 ; the Apple menu: desk accessories
            Tool  _FixAppleMenu
            pha
            Tool  _FixMenuBar
            pla
            Tool  _DrawMenuBar
            rts

* AddMenu: a menu string's address on the stack (pushed before the JSR)
AddMenu     pla
            sta   :ret
            pha                     ; result: the menu's handle
            pha
            lda   7,s
            pha
            lda   7,s
            pha
            Tool  _NewMenu
            pea   0                 ; at the front
            Tool  _InsertMenu
            pla
            pla
            lda   :ret
            pha
            rts
:ret        dw    0

DoMenu      lda   EventRec+TaskData
            ldx   #0
:find       ldy   MenuTab,x
            beq   :done
            cmp   MenuTab,x
            beq   :found
            inx
            inx
            inx
            inx
            bra   :find
:found      phx                     ; (the title back to normal first)
            jsr   :done
            plx
            jmp   (MenuTab+2,x)
:done       pea   0                 ; unhighlight the menu title
            lda   EventRec+TaskData+2
            pha
            Tool  _HiliteMenu
            rts

MenuTab     da    iAbout,About
            da    iAdd,AddApp
            da    iEdit,EditToggle
            da    iChange,ChangeApp
            da    iRename,RenameSlot
            da    iRemove,RemoveSlot
            da    iLeft,MoveLeft
            da    iRight,MoveRight
            da    iQuit,QuitFinder
            da    0

iQuit       equ   256
iAbout      equ   257
iAdd        equ   260
iEdit       equ   261
iChange     equ   262
iRename     equ   263
iRemove     equ   264
iLeft       equ   265
iRight      equ   266

About       ldx   #AboutTx
* Alert: X = an alert string (AlertWindow's form)
Alert       pha
            pea   0
            PushLong 0
            pea   ^AboutTx
            phx
            Tool  _AlertWindow
            pla
            rts

* MsgStart, MsgCat: X = a C string as the start of MsgBuf, onto its
* end; MsgAlert: MsgBuf as an alert
MsgStart    stz   MsgBuf
MsgCat      stx   SP1
            ldx   #0
:end        lda   MsgBuf,x
            and   #$FF
            beq   :cp
            inx
            bra   :end
:cp         ldy   #0
            sep   #$20
            mx    %10
:c          lda   (SP1),y
            sta   MsgBuf,x
            beq   :x
            inx
            iny
            cpx   #250
            bcc   :c
            lda   #0
            sta   MsgBuf,x
:x          rep   #$20
            mx    %00
            rts
MsgAlert    ldx   #MsgBuf
            jmp   Alert

*-------------------------------------------------------------
* Editing the slots
*-------------------------------------------------------------
EditToggle  lda   EditMode
            eor   #1
            sta   EditMode
            pha                     ; the check mark
            pea   iEdit
            Tool  _CheckMItem
            ldx   #TitleTx
            lda   EditMode
            beq   :t
            ldx   #EditTitleTx
            lda   Sel               ; (a slot chosen, if there are any)
            cmp   NSlots
            bcc   :t
            stz   Sel
:t          pea   ^TitleTx
            phx
            PushLongAt WinPtr
            Tool  _SetWTitle
            jmp   Redraw

* NeedSel: carry clear if a slot is chosen (Edit mode), else a word
NeedSel     lda   EditMode
            beq   :no
            lda   Sel
            cmp   NSlots
            bcs   :no
            rts
:no         ldx   #NeedSelTx
            jsr   Alert
            sec
            rts

AddApp      lda   NSlots
            cmp   #MaxSlots
            bcc   :room
            ldx   #FullTx
            jmp   Alert
:room       jsr   AskApp
            bcs   :x
            lda   NSlots
            sta   CurI
            jsr   SetSlotPath
            inc   NSlots
            lda   EditMode
            beq   :s
            lda   CurI
            sta   Sel
:s          jsr   SaveSlots
            jmp   Relayout
:x          rts

ChangeApp   jsr   NeedSel
            bcs   :x
            jsr   AskApp
            bcs   :x
            lda   Sel
            sta   CurI
            jsr   SetSlotPath
            jsr   SaveSlots
            jmp   Redraw
:x          rts

* SetSlotPath: PathBuf as slot CurI's app (its name from it)
SetSlotPath lda   CurI
            jsr   PathOf
            tay
            ldx   #PathBuf
            jsr   CopyGS
            lda   CurI
            jsr   DefaultName
            Tool  _WaitCursor
            lda   CurI
            jsr   Refresh
            Tool  _InitCursor
            rts

RenameSlot  jsr   NeedSel
            bcs   :x
            lda   Sel
            jsr   NameOf
            tax
            ldy   #InBuf
            jsr   CopyC
            jsr   InputBox
            bcs   :x
            lda   InBuf
            and   #$FF
            bne   :named
            lda   Sel               ; (empty: the file's name again)
            jsr   DefaultName
            bra   :save
:named      lda   Sel
            jsr   NameOf
            tay
            ldx   #InBuf
            jsr   CopyC
:save       jsr   SaveSlots
:x          jmp   Redraw

RemoveSlot  jsr   NeedSel
            bcs   :x
            lda   Sel               ; (moved to the end, then dropped)
            sta   T6
:l          lda   T6
            inc
            cmp   NSlots
            bcs   :last
            sta   T7
            jsr   SwapSlots
            inc   T6
            bra   :l
:last       dec   NSlots
            lda   Sel
            cmp   NSlots
            bcc   :s
            lda   NSlots
            dec
            sta   Sel               ; (none left: $FFFF, no slot)
:s          jsr   SaveSlots
            jmp   Relayout
:x          rts

MoveLeft    jsr   NeedSel
            bcs   :x
            lda   Sel
            beq   :x
            sta   T7
            dec
            sta   T6
            sta   Sel
            jsr   SwapSlots
            jsr   SaveSlots
            jmp   Redraw
:x          rts

MoveRight   jsr   NeedSel
            bcs   :x
            lda   Sel
            sta   T6
            inc
            cmp   NSlots
            bcs   :x
            sta   T7
            sta   Sel
            jsr   SwapSlots
            jsr   SaveSlots
            jmp   Redraw
:x          rts

* SwapSlots: slots T6 and T7 change places
SwapSlots   lda   T6
            jsr   PathOf
            pha
            lda   T7
            jsr   PathOf
            tay
            plx
            lda   #PathSz
            jsr   SwapMem
            lda   T6
            jsr   NameOf
            pha
            lda   T7
            jsr   NameOf
            tay
            plx
            lda   #NameSz
            jsr   SwapMem
            lda   T6
            jsr   DateOf
            pha
            lda   T7
            jsr   DateOf
            tay
            plx
            lda   #DateSz
            jsr   SwapMem
            lda   T6
            jsr   IconOf
            pha
            lda   T7
            jsr   IconOf
            tay
            plx
            lda   #IconMax
            jsr   SwapMem
            ldy   #0                ; the words: type, icon found, file there
:w          phy
            lda   T6
            asl
            clc
            adc   WordArrs,y
            tax
            lda   T7
            asl
            clc
            adc   WordArrs,y
            tay
            lda   #2
            jsr   SwapMem
            ply
            iny
            iny
            cpy   #6
            bcc   :w
            rts
WordArrs    da    SlotType,SlotHas,SlotOK

* SwapMem: A bytes (even) at X and at Y change places
SwapMem     sta   T5
            stx   SP1
            sty   SP2
            ldy   #0
:l          cpy   T5
            bcs   :x
            lda   (SP1),y
            tax
            lda   (SP2),y
            sta   (SP1),y
            txa
            sta   (SP2),y
            iny
            iny
            bra   :l
:x          rts

* AskApp: Standard File: an application chosen: PathBuf, carry clear
AskApp      lda   #3                ; handles to the name and path, please
            sta   Reply+8
            sta   Reply+14
            pea   120               ; where (ignored when centred)
            pea   40
            pea   0                 ; prompt: a Pascal string
            PushLong AskPrompt
            PushLong 0              ; no filter
            PushLong 0              ; every file type
            PushLong Reply
            Tool  _SFGetFile2
            lda   Reply             ; good?
            bne   :good
            sec
            rts
:good       lda   Reply+16          ; the path handle: buffer size, string
            sta   Ptr
            lda   Reply+18
            sta   Ptr+2
            lda   [Ptr]
            tax
            ldy   #2
            lda   [Ptr],y
            sta   Ptr+2
            stx   Ptr
            lda   [Ptr],y           ; its length
            cmp   #PathMax+1
            bcs   :long
            sta   PathBuf
            tax
            ldy   #4
            sep   #$20
            mx    %10
:c          cpx   #0
            beq   :cd
            lda   [Ptr],y
            sta   PathBuf-2,y
            iny
            dex
            bra   :c
:cd         rep   #$20
            mx    %00
            jsr   FreeReply
            lda   Reply+2           ; an application?
            cmp   #tS16
            beq   :ok
            cmp   #tSYS
            beq   :ok
            ldx   #NotAppTx
            jsr   Alert
            sec
            rts
:ok         clc
            rts
:long       jsr   FreeReply
            ldx   #LongTx
            jsr   Alert
            sec
            rts

FreeReply   PushLongAt Reply+10
            Tool  _DisposeHandle
            PushLongAt Reply+16
            Tool  _DisposeHandle
            rts

*-------------------------------------------------------------
* InputBox: InBuf (a C string) edited in a small window: Return
* or Enter: carry clear; Escape: carry set
*-------------------------------------------------------------
InputBox    pha
            pha
            PushLong InParms
            Tool  _NewWindow
            pla
            sta   InWin
            pla
            sta   InWin+2
            PushLongAt InWin
            Tool  _SetPort
            pea   $0000
            Tool  _SetForeColor
            pea   $000F
            Tool  _SetBackColor
:draw       PushLong InRect
            Tool  _EraseRect
            lda   #10
            sta   PX
            lda   #13
            sta   PY
            ldx   #InQTx
            jsr   DrawAt
            pea   1
            pea   1
            Tool  _SetPenSize
            pea   0
            Tool  _SetSolidPenPat
            PushLong InField
            Tool  _FrameRect
            lda   #14
            sta   PX
            lda   #31
            sta   PY
            ldx   #InBuf
            jsr   DrawAt
            ldx   #CaretTx
            jsr   DrawStr
            lda   #10
            sta   PX
            lda   #50
            sta   PY
            ldx   #InHintTx
            jsr   DrawAt
:wait       pha
            pea   $0028             ; keys
            PushLong EvRec2
            Tool  _GetNextEvent
            pla
            beq   :wait
            lda   EvRec2+2
            and   #$7F
            cmp   #K_RETURN
            beq   :ok
            cmp   #3                ; (Enter)
            beq   :ok
            cmp   #K_ESC
            beq   :cancel
            ldx   #0                ; (X: the end of InBuf)
:end        lda   InBuf,x
            and   #$FF
            beq   :at
            inx
            bra   :end
:at         lda   EvRec2+2
            and   #$7F
            cmp   #K_DEL
            beq   :rub
            cmp   #K_LEFT
            beq   :rub
            cmp   #' '
            bcc   :wait
            cpx   #NameMax
            bcs   :wait
            sta   InBuf,x           ; (and the zero after it)
            jmp   :draw
:rub        cpx   #0
            beq   :wait
            stz   InBuf-1,x         ; (the last one and the zero: a word)
            jmp   :draw
:ok         jsr   :close
            clc
            rts
:cancel     jsr   :close
            sec
            rts
:close      PushLongAt InWin
            Tool  _CloseWindow
            jmp   UsePort

*-------------------------------------------------------------
* The window
*-------------------------------------------------------------
* Layout: columns, rows and the window's size and place for NSlots
Layout      lda   NSlots
            cmp   #MaxCols+1
            bcc   :a
            lda   #MaxCols
:a          cmp   #MinCols
            bcs   :b
            lda   #MinCols
:b          sta   Cols
            stz   Rows              ; rows: NSlots / Cols, rounded up
            lda   NSlots
:rl         beq   :rd
            inc   Rows
            sec
            sbc   Cols
            beq   :rd
            bcs   :rl
:rd         lda   Rows
            bne   :r1
            inc   Rows
:r1         lda   #Margin*2         ; width
            ldx   Cols
:w          clc
            adc   #CellW
            dex
            bne   :w
            sta   WinW
            lda   #Margin*2         ; height
            ldx   Rows
:h          clc
            adc   #CellH
            dex
            bne   :h
            sta   WinH
            lda   #640              ; centred
            sec
            sbc   WinW
            lsr
            and   #$FFFC
            sta   WinL
            lda   WinH              ; the local rectangle
            sta   ContRect+4
            lda   WinW
            sta   ContRect+6
            lda   #WinTop           ; where on the screen (for NewWindow)
            sta   WinParms+62
            clc
            adc   WinH
            sta   WinParms+66
            lda   WinL
            sta   WinParms+64
            clc
            adc   WinW
            sta   WinParms+68
            rts

MakeWindow  pha
            pha
            PushLong WinParms
            Tool  _NewWindow
            pla
            sta   WinPtr
            pla
            sta   WinPtr+2
            jmp   UsePort

UsePort     PushLongAt WinPtr
            Tool  _SetPort
            rts

* Relayout: the window to the size for NSlots, drawn again
Relayout    jsr   Layout
            lda   WinW
            pha
            lda   WinH
            pha
            PushLongAt WinPtr
            Tool  _SizeWindow
            lda   WinL
            pha
            pea   WinTop
            PushLongAt WinPtr
            Tool  _MoveWindow
* Redraw: all of it drawn again (on the next update)
Redraw      jsr   UsePort
            PushLong ContRect
            Tool  _InvalRect
            rts

* The window's content procedure (the Window Manager calls it to draw)
ContentProc phb
            phk
            plb
            phd
            lda   MyDP
            tcd
            jsr   DrawAll
            pld
            plb
            rtl

DrawAll     pea   $0000             ; black on white
            Tool  _SetForeColor
            pea   $000F
            Tool  _SetBackColor
            PushLong ContRect
            Tool  _EraseRect
            lda   NSlots
            bne   :slots
            lda   #Margin+10        ; none yet: what to do
            sta   PX
            lda   #Margin+20
            sta   PY
            ldx   #EmptyTx
            jsr   DrawAt
            lda   #Margin+10
            sta   PX
            lda   #Margin+32
            sta   PY
            ldx   #Empty2Tx
            jmp   DrawAt
:slots      stz   DrawI
:l          lda   DrawI
            jsr   DrawSlot
            inc   DrawI
            lda   DrawI
            cmp   NSlots
            bcc   :l
            rts

* DrawSlot: A = a slot: its icon, name and date in its cell
DrawSlot    sta   CurI
            jsr   CellXY
            lda   CurI
            asl
            tax
            lda   SlotHas,x         ; its icon, or the generic one
            beq   :gen
            lda   CurI
            jsr   IconOf
            bra   :icon
:gen        lda   #GenIcon
:icon       sta   SP1
            ldy   #6                ; width (icon pixels: two screen pixels)
            lda   (SP1),y
            cmp   #CellW/2
            bcc   :wok
            lda   #CellW/2-2
:wok        sta   T0
            lda   #CellW            ; x: centred
            sec
            sbc   T0
            sbc   T0
            lsr
            clc
            adc   CellX
            and   #$FFFC
            sta   T1
            ldy   #4                ; y: its bottom 4 above the name
            lda   (SP1),y
            cmp   #25
            bcc   :hok
            lda   #24
:hok        sta   T0
            lda   CellY
            clc
            adc   #28
            sec
            sbc   T0
            sta   T2
            pea   ^GenIcon
            lda   SP1
            pha
            lda   CurI              ; display mode: dimmed if it is missing
            asl
            tax
            lda   SlotOK,x
            beq   :off
            pea   0
            bra   :mode
:off        pea   $0004
:mode       lda   T1
            pha
            lda   T2
            pha
            Tool  _DrawIcon
            lda   CurI              ; its name
            jsr   NameOf
            tax
            ldy   #38
            jsr   CellText
            lda   CurI              ; the file's date
            jsr   DateOf
            tax
            ldy   #48
            jsr   CellText
            lda   EditMode          ; chosen (Edit mode): a frame round it
            beq   :x
            lda   CurI
            cmp   Sel
            bne   :x
            pea   2
            pea   1
            Tool  _SetPenSize
            pea   0
            Tool  _SetSolidPenPat
            lda   CellY
            inc
            sta   FrRect
            lda   CellX
            inc
            inc
            sta   FrRect+2
            lda   CellY
            clc
            adc   #CellH-1
            sta   FrRect+4
            lda   CellX
            clc
            adc   #CellW-2
            sta   FrRect+6
            PushLong FrRect
            Tool  _FrameRect
:x          rts

* CellText: X = a C string, centred in the cell (made to fit), its
* baseline Y below the cell's top
CellText    tya
            clc
            adc   CellY
            sta   PY
            ldy   #LineBuf
            jsr   CopyC
:fit        ldx   #LineBuf
            jsr   StrWidth
            cmp   #CellW-6
            bcc   :ok
            ldx   #0                ; too wide: the last letter off
:e          lda   LineBuf,x
            and   #$FF
            beq   :cut
            inx
            bra   :e
:cut        cpx   #0
            beq   :ok
            sep   #$20
            mx    %10
            stz   LineBuf-1,x
            rep   #$20
            mx    %00
            bra   :fit
:ok         sta   T0
            lda   #CellW
            sec
            sbc   T0
            lsr
            clc
            adc   CellX
            sta   PX
            ldx   #LineBuf
            jmp   DrawAt

* CellXY: A = a slot: CellX, CellY = its cell's top left
CellXY      ldx   #0                ; column, row
:d          cmp   Cols
            bcc   :r
            sbc   Cols
            inx
            bra   :d
:r          tay
            lda   #Margin
:cx         dey
            bmi   :cxd
            clc
            adc   #CellW
            bra   :cx
:cxd        sta   CellX
            lda   #Margin
:cy         dex
            bmi   :cyd
            clc
            adc   #CellH
            bra   :cy
:cyd        sta   CellY
            rts

* DrawAt: X = a C string (this bank) at PX, PY (the baseline)
DrawAt      phx
            lda   PX
            pha
            lda   PY
            pha
            Tool  _MoveTo
            plx
DrawStr     pea   ^LineBuf
            phx
            Tool  _DrawCString
            rts

* StrWidth: X = a C string: A = its width in pixels
StrWidth    pha
            pea   ^LineBuf
            phx
            Tool  _CStringWidth
            pla
            rts

*-------------------------------------------------------------
* Memory
*-------------------------------------------------------------
* AllocMem: 64K for icon files (IPtr)
AllocMem    pha                     ; result: handle
            pha
            pea   1                 ; $10000 bytes
            pea   0
            lda   UserID
            pha
            pea   $C000             ; locked, fixed
            pea   0
            pea   0
            Tool  _NewHandle
            plx
            ply
            bcs   :err
            stx   Ptr
            sty   Ptr+2
            lda   [Ptr]
            sta   IPtr
            ldy   #2
            lda   [Ptr],y
            sta   IPtr+2
            clc
:err        rts

*-------------------------------------------------------------
* The slots' data: addresses
*-------------------------------------------------------------
* PathOf, NameOf, DateOf, IconOf: A = a slot: A = the address of its
* path (GS/OS string), name (C string), date (C string), icon record
PathOf      sta   PO1               ; * 260: * 256 + * 4
            xba
            and   #$FF00
            sta   PO2
            lda   PO1
            asl
            asl
            clc
            adc   PO2
            adc   #SlotPath
            rts
PO1         dw    0
PO2         dw    0
NameOf      asl
            asl
            asl
            asl
            asl
            clc
            adc   #SlotName
            rts
DateOf      asl
            asl
            asl
            asl
            clc
            adc   #SlotDate
            rts
IconOf      xba                     ; * 1024
            and   #$FF00
            asl
            asl
            clc
            adc   #SlotIcon
            rts

*-------------------------------------------------------------
* Strings
*-------------------------------------------------------------
* CopyC: the C string at X to Y
CopyC       stx   SP1
            sty   SP2
            ldy   #0
            sep   #$20
            mx    %10
:c          lda   (SP1),y
            sta   (SP2),y
            beq   :x
            iny
            bra   :c
:x          rep   #$20
            mx    %00
            rts

* CopyGS: the GS/OS string at X to Y
CopyGS      stx   SP1
            sty   SP2
            lda   (SP1)
            sta   (SP2)
            inc
            inc
            sta   T5
            ldy   #2
            sep   #$20
            mx    %10
:c          cpy   T5
            bcs   :x
            lda   (SP1),y
            sta   (SP2),y
            iny
            bra   :c
:x          rep   #$20
            mx    %00
            rts

* IsSep: A = a character: zero flag set if it is ':' or '/'
IsSep       cmp   #':'
            beq   :x
            cmp   #'/'
:x          rts

* LastSep: the GS/OS string at SP1: A = where its last ':' or '/' is
* (its position, 0 = the first character); carry set if none
LastSep     lda   (SP1)
            tay
:l          dey
            bmi   :no
            phy
            iny
            iny
            lda   (SP1),y
            ply
            and   #$FF
            jsr   IsSep
            bne   :l
            tya
            clc
            rts
:no         sec
            rts

* Upper: A = a character, as a capital
Upper       cmp   #'a'
            bcc   :x
            cmp   #'z'+1
            bcs   :x
            sbc   #$1F              ; (carry clear: - $20)
:x          rts

* DefaultName: A = a slot: its name from its file's name (without
* ".SYSTEM")
DefaultName sta   T6
            jsr   PathOf
            sta   SP1
            jsr   LastSep
            bcc   :s
            lda   #$FFFF            ; (no ':': all of it)
:s          inc                     ; (the first character of the name)
            sta   T4
            lda   T6
            jsr   NameOf
            sta   SP2
            lda   (SP1)
            sta   T3                ; (the path's length)
            ldx   #0                ; X: the name's length
:c          lda   T4
            cmp   T3
            bcs   :end
            cpx   #NameMax
            bcs   :end
            inc
            inc
            tay
            lda   (SP1),y
            phx
            ply
            sep   #$20
            mx    %10
            sta   (SP2),y
            rep   #$20
            mx    %00
            inx
            inc   T4
            bra   :c
:end        txy
            sep   #$20
            mx    %10
            lda   #0
            sta   (SP2),y
            rep   #$20
            mx    %00
            cpx   #8                ; ends in .SYSTEM? (and more before it)
            bcc   :x
            txa
            sec
            sbc   #7
            tay
            ldx   #0
:sys        lda   (SP2),y
            and   #$FF
            jsr   Upper
            sep   #$20
            mx    %10
            cmp   SysTx,x
            rep   #$20
            mx    %00
            bne   :x
            iny
            inx
            cpx   #7
            bcc   :sys
            tya                     ; yes: cut there
            sec
            sbc   #7
            tay
            sep   #$20
            mx    %10
            lda   #0
            sta   (SP2),y
            rep   #$20
            mx    %00
:x          rts
SysTx       asc   '.SYSTEM'

*-------------------------------------------------------------
* The slots file: name=path lines (CR or LF); # or ; starts a note
*-------------------------------------------------------------
LoadSlots   stz   NSlots
            ldx   #SlotsFile
            lda   #1
            jsr   OpenFile
            bcs   :x
            GSOS  _GetEOFGS;EOFParms
            lda   EOFParms+4
            ldx   EOFParms+6
            bne   :max
            cmp   #FileMax
            bcc   :n
:max        lda   #FileMax
:n          sta   RWParms+8
            stz   RWParms+10
            stz   RWParms+12
            lda   #FileBuf
            sta   RWParms+4
            lda   MyBank
            sta   RWParms+6
            GSOS  _ReadGS;RWParms
            lda   RWParms+12
            sta   FileLen
            GSOS  _CloseGS;CloseParms
            jsr   ParseSlots
:x          rts

ParseSlots  stz   FPos
:line       lda   NSlots
            cmp   #MaxSlots
            bcs   :done
            lda   FPos
            cmp   FileLen
            bcs   :done
            ldx   FPos              ; a line into LineBuf
            ldy   #0
:c          cpx   FileLen
            bcs   :eol
            lda   FileBuf,x
            and   #$FF
            inx
            cmp   #$0D
            beq   :eol
            cmp   #$0A
            beq   :eol
            cpy   #LineMax
            bcs   :c                ; (too long: the rest dropped)
            sta   LineBuf,y         ; (and a zero after it)
            iny
            bra   :c
:eol        stx   FPos
            lda   #0
            sta   LineBuf,y
            cpy   #0
            beq   :line
            lda   LineBuf
            and   #$FF
            cmp   #'#'
            beq   :line
            cmp   #';'
            beq   :line
            jsr   AddLine
            bra   :line
:done       rts

* AddLine: LineBuf (name=path, or a path) as a new slot
AddLine     ldx   #0                ; where is the '='?
:f          lda   LineBuf,x
            and   #$FF
            beq   :none
            cmp   #'='
            beq   :eq
            inx
            bra   :f
:none       stz   T3                ; no name: all of it the path
            stz   T4
            bra   :path
:eq         stx   T3                ; the name's length
            inx
            stx   T4                ; where the path starts
:path       lda   NSlots
            jsr   PathOf
            sta   SP2
            ldx   T4
            ldy   #2
:pc         lda   LineBuf,x
            and   #$FF
            beq   :pe
            cpy   #PathMax+2
            bcs   :x                ; (too long)
            sep   #$20
            mx    %10
            sta   (SP2),y
            rep   #$20
            mx    %00
            inx
            iny
            bra   :pc
:pe         dey
            dey
            beq   :x                ; (no path)
            tya
            sta   (SP2)
            lda   NSlots
            jsr   NameOf
            sta   SP2
            ldx   #0
            ldy   #0
:nc         cpx   T3
            bcs   :ne
            cpy   #NameMax
            bcs   :ne
            lda   LineBuf,x
            sep   #$20
            mx    %10
            sta   (SP2),y
            rep   #$20
            mx    %00
            inx
            iny
            bra   :nc
:ne         sep   #$20
            mx    %10
            lda   #0
            sta   (SP2),y
            rep   #$20
            mx    %00
            cpy   #0
            bne   :named
            lda   NSlots
            jsr   DefaultName
:named      inc   NSlots
:x          rts

* SaveSlots: the slots written to the file again
SaveSlots   ldy   #0                ; Y: the text's length
            stz   T6
:s          lda   T6
            cmp   NSlots
            bcs   :built
            jsr   NameOf            ; name=path, CR
            tax
:n          lda   |0,x
            and   #$FF
            beq   :nd
            sta   FileBuf,y
            inx
            iny
            bra   :n
:nd         lda   #'='
            sta   FileBuf,y
            iny
            sty   T5
            lda   T6
            jsr   PathOf
            tax
            lda   |0,x
            sta   T4
            ldy   T5
:pc         lda   T4
            beq   :pd
            lda   |2,x
            and   #$FF
            sta   FileBuf,y
            inx
            iny
            dec   T4
            bra   :pc
:pd         lda   #$0D
            sta   FileBuf,y
            iny
            inc   T6
            bra   :s
:built      sty   FileLen
            lda   #SlotsFile
            ldx   #DestParms
            jsr   SetPath
            GSOS  _DestroyGS;DestParms
            lda   #SlotsFile
            ldx   #CreateParms
            jsr   SetPath
            GSOS  _CreateGS;CreateParms
            bcs   :err
            ldx   #SlotsFile
            lda   #2
            jsr   OpenFile
            bcs   :err
            lda   #FileBuf
            sta   RWParms+4
            lda   MyBank
            sta   RWParms+6
            lda   FileLen
            sta   RWParms+8
            stz   RWParms+10
            GSOS  _WriteGS;RWParms
            php
            GSOS  _CloseGS;CloseParms
            plp
            bcs   :err
            rts
:err        ldx   #SaveErrTx
            jmp   Alert

* SetPath: A = a GS/OS string as the path of the parameters at X
SetPath     sta   |2,x
            lda   MyBank
            sta   |4,x
            rts

* OpenFile: X = a GS/OS path, A = access (1 read, 2 write): carry
* clear if open (RWParms, CloseParms and EOFParms set for it)
OpenFile    sta   OpenParms+8
            stx   OpenParms+4
            lda   MyBank
            sta   OpenParms+6
            GSOS  _OpenGS;OpenParms
            bcs   :x
            lda   OpenParms+2
            sta   RWParms+2
            sta   CloseParms+2
            sta   EOFParms+2
:x          rts

*-------------------------------------------------------------
* A slot's file: its type, date and icon
*-------------------------------------------------------------
ScanAll     stz   T6
:l          lda   T6
            cmp   NSlots
            bcs   :x
            jsr   Refresh
            inc   T6
            bra   :l
:x          rts

* Refresh: A = a slot: its file's type and date, its icon
Refresh     pha
            jsr   FileInfo
            pla
            jmp   FindIcon

* FileInfo: A = a slot (CurI): SlotType, SlotOK, its date
FileInfo    sta   CurI
            jsr   PathOf
            ldx   #GFIParms
            jsr   SetPath
            GSOS  _GetFileInfoGS;GFIParms
            php
            lda   CurI
            asl
            tax
            plp
            bcc   :ok
            stz   SlotOK,x
            stz   SlotType,x
            lda   CurI
            jsr   DateOf
            tay
            ldx   #MissingTx
            jmp   CopyC
:ok         lda   #1
            sta   SlotOK,x
            lda   GFIParms+8
            sta   SlotType,x
            ldx   #0                ; "04 Nov 10:22"
            lda   GFIParms+28       ; day (0-30)
            and   #$FF
            inc
            jsr   TwoDig
            lda   #' '
            jsr   PutCh
            lda   GFIParms+29       ; month (0-11)
            and   #$FF
            cmp   #12
            bcc   :m
            lda   #0
:m          asl
            asl
            tay
            lda   MonthTx,y
            jsr   PutCh
            lda   MonthTx+1,y
            jsr   PutCh
            lda   MonthTx+2,y
            jsr   PutCh
            lda   #' '
            jsr   PutCh
            lda   GFIParms+26       ; hour
            and   #$FF
            jsr   TwoDig
            lda   #':'
            jsr   PutCh
            lda   GFIParms+25       ; minute
            and   #$FF
            jsr   TwoDig
            lda   #0
            jsr   PutCh
            lda   CurI
            jsr   DateOf
            tay
            ldx   #DateTmp
            jmp   CopyC
MonthTx     asc   'Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec '

* PutCh: A = a character into DateTmp at X (X moves on)
PutCh       sep   #$20
            mx    %10
            sta   DateTmp,x
            rep   #$20
            mx    %00
            inx
            rts

* TwoDig: A = 0-99 as two digits into DateTmp at X
TwoDig      ldy   #'0'
:t          cmp   #10
            bcc   :o
            sbc   #10
            iny
            bra   :t
:o          pha
            tya
            jsr   PutCh
            pla
            ora   #'0'
            jmp   PutCh

* FindIcon: A = a slot (CurI): its Finder icon (SlotHas), looked for
* in the Icons folder beside it, then in its disk's Icons folder
FindIcon    sta   CurI
            asl
            tax
            stz   SlotHas,x
            lda   SlotOK,x
            bne   :ok
            rts
:ok         lda   SlotType,x
            sta   CurType
            lda   CurI
            jsr   PathOf
            sta   SP1
            jsr   LastSep
            bcc   :sep
            rts
:sep        sta   DirLen
            lda   (SP1)
            sta   T5                ; (the path's length)
            ldy   DirLen            ; AppName: the file's name in capitals
            iny
            ldx   #0
:an         cpy   T5
            bcs   :and
            cpx   #63
            bcs   :and
            phy
            iny
            iny
            lda   (SP1),y
            ply
            and   #$FF
            jsr   Upper
            sep   #$20
            mx    %10
            sta   AppName,x
            rep   #$20
            mx    %00
            inx
            iny
            bra   :an
:and        stz   AppName,x         ; (a zero word)
            ldx   DirLen            ; its folder's Icons
            jsr   CopyPart
            jsr   ScanDir
            bcc   :x
            lda   CurI              ; (SP1 used meanwhile)
            jsr   PathOf
            sta   SP1
            ldy   #1                ; the disk's: the second ':' or '/'
:fs         lda   (SP1)
            sta   T5
            cpy   T5
            bcs   :x
            phy
            iny
            iny
            lda   (SP1),y
            ply
            and   #$FF
            jsr   IsSep
            beq   :root
            iny
            bra   :fs
:root       cpy   DirLen
            beq   :x                ; (the same folder)
            tyx
            jsr   CopyPart
            jsr   ScanDir
:x          rts


* CopyPart: the first X characters of the GS/OS string at SP1 into
* ScanPath, then ":Icons"
CopyPart    stx   T5
            ldy   #0
:c          cpy   T5
            bcs   :d
            iny
            iny
            lda   (SP1),y
            dey
            dey
            sep   #$20
            mx    %10
            sta   ScanPath+2,y
            rep   #$20
            mx    %00
            iny
            bra   :c
:d          ldx   #0
:i          lda   IconsTx,x
            and   #$FF
            beq   :e
            sep   #$20
            mx    %10
            sta   ScanPath+2,y
            rep   #$20
            mx    %00
            iny
            inx
            bra   :i
:e          sty   ScanPath
            rts
IconsTx     asc   ':Icons',00

* ScanDir: the Finder icon files ($CA) in the folder ScanPath: one for
* slot CurI (AppName, CurType)? carry clear if found
ScanDir     ldx   #ScanPath
            lda   #1
            jsr   OpenFile
            bcc   :open
            rts
:open       lda   OpenParms+2
            sta   DirRef
            sta   DirParms+2
            stz   Found
:next       lda   #1
            sta   DirParms+6        ; base 1, displacement 1: the next
            sta   DirParms+8
            GSOS  _GetDirEntryGS;DirParms
            bcs   :end
            lda   DirParms+16
            cmp   #tICN
            bne   :next
            lda   DirParms+20       ; (64K at most)
            bne   :next
            lda   DirParms+18
            beq   :next
            sta   IconLen
            jsr   FilePathOf
            bcs   :next
            jsr   LoadIcons
            bcs   :next
            jsr   MatchIcons
            bcs   :next
            inc   Found
:end        lda   DirRef
            sta   CloseParms+2
            GSOS  _CloseGS;CloseParms
            lda   Found
            beq   :no
            clc
            rts
:no         sec
            rts

* FilePathOf: FilePath = ScanPath ':' and the entry's name
FilePathOf  lda   ScanPath
            clc
            adc   NameRes+2
            inc
            cmp   #PathMax
            bcs   :x
            ldx   #ScanPath
            ldy   #FilePath
            jsr   CopyGS
            lda   FilePath
            tay
            lda   #':'
            sep   #$20
            mx    %10
            sta   FilePath+2,y
            rep   #$20
            mx    %00
            iny
            ldx   #0
:c          cpx   NameRes+2
            bcs   :d
            lda   NameRes+4,x
            sep   #$20
            mx    %10
            sta   FilePath+2,y
            rep   #$20
            mx    %00
            inx
            iny
            bra   :c
:d          sty   FilePath
            clc
:x          rts

* LoadIcons: FilePath (IconLen bytes) into the 64K at IPtr
LoadIcons   ldx   #FilePath
            lda   #1
            jsr   OpenFile
            bcs   :x
            lda   IPtr
            sta   RWParms+4
            lda   IPtr+2
            sta   RWParms+6
            lda   IconLen
            sta   RWParms+8
            stz   RWParms+10
            stz   RWParms+12
            GSOS  _ReadGS;RWParms
            lda   RWParms+12
            sta   IconLen
            GSOS  _CloseGS;CloseParms
            clc
:x          rts

* MatchIcons: an entry in the icon file for slot CurI? Its large icon
* copied to the slot (SlotHas), carry clear
MatchIcons  lda   #26               ; (past the file's header)
            sta   IPos
:e          lda   IPos
            clc
            adc   #2
            bcc   :jx1807_0
            jmp   :no
:jx1807_0
            cmp   IconLen
            beq   :in
            bcc   :jx1812_0
            jmp   :no
:jx1812_0
:in         ldy   IPos
            lda   [IPtr],y          ; the entry's length (0: no more)
            sta   ELen
            bne   :jx1818_0
            jmp   :no
:jx1818_0
            cmp   #94
            bcs   :jx1822_0
            jmp   :skip
:jx1822_0
            lda   IPos
            clc
            adc   ELen
            bcc   :jx1828_0
            jmp   :no
:jx1828_0
            cmp   IconLen
            beq   :fits
            bcc   :jx1833_0
            jmp   :no
:jx1833_0
:fits       lda   IPos              ; its file type: 0 (any) or the app's
            clc
            adc   #82
            tay
            lda   [IPtr],y
            beq   :ty
            cmp   CurType
            bne   :skip
:ty         lda   IPos              ; its name (a pattern; none: skip it)
            clc
            adc   #66
            tay
            lda   [IPtr],y
            and   #$FF
            beq   :skip
            cmp   #16
            bcs   :skip
            sta   T0
            ldx   #0
:pc         iny
            lda   [IPtr],y
            and   #$FF
            jsr   Upper
            sep   #$20
            mx    %10
            sta   PatBuf,x
            rep   #$20
            mx    %00
            inx
            cpx   T0
            bcc   :pc
            stz   PatBuf,x
            jsr   PatMatch
            bcs   :skip
            lda   IPos              ; the large icon: its size
            clc
            adc   #86
            sta   T1
            inc
            inc
            tay
            lda   [IPtr],y
            cmp   #IconMax-8/2      ; (Merlin: left to right)
            bcs   :skip
            asl
            clc
            adc   #8
            sta   T2
            lda   CurI
            jsr   IconOf
            tax
            ldy   T1
:cp         lda   [IPtr],y          ; (an even number of bytes)
            sta   |0,x
            inx
            inx
            iny
            iny
            dec   T2
            dec   T2
            bne   :cp
            lda   CurI
            asl
            tax
            lda   #1
            sta   SlotHas,x
            clc
            rts
:skip       lda   IPos
            clc
            adc   ELen
            bcs   :no
            sta   IPos
            jmp   :e
:no         sec
            rts

* PatMatch: AppName against PatBuf (both in capitals), '=' in the
* pattern standing for any characters: carry clear if they match
PatMatch    ldx   #0
            ldy   #0
            lda   #$FFFF
            sta   Star
:loop       lda   AppName,y
            and   #$FF
            beq   :tail
            lda   PatBuf,x
            and   #$FF
            cmp   #'='
            beq   :star
            sta   T3
            lda   AppName,y
            and   #$FF
            cmp   T3
            bne   :miss
            inx
            iny
            bra   :loop
:star       stx   Star
            sty   Mark
            inx
            bra   :loop
:miss       lda   Star
            bmi   :fail
            tax
            inx
            inc   Mark
            ldy   Mark
            bra   :loop
:tail       lda   PatBuf,x
            and   #$FF
            beq   :ok
            cmp   #'='
            bne   :fail
            inx
            bra   :tail
:ok         clc
            rts
:fail       sec
            rts

            put   genicon.s

*-------------------------------------------------------------
* Data
*-------------------------------------------------------------
MyDP        dw    0
MyBank      dw    0
UserID      dw    0
SSRef       adrl  0
WinPtr      adrl  0
InWin       adrl  0
ClickPt     dw    0,0
NSlots      dw    0
Sel         dw    $FFFF             ; the slot chosen in Edit mode
EditMode    dw    0
Cols        dw    0
Rows        dw    0
WinW        dw    0
WinH        dw    0
WinL        dw    0
CellX       dw    0
CellY       dw    0
CurI        dw    0
CurType     dw    0
DrawI       dw    0
DirLen      dw    0
DirRef      dw    0
Found       dw    0
IconLen     dw    0
IPos        dw    0
ELen        dw    0
Star        dw    0
Mark        dw    0
FPos        dw    0
FileLen     dw    0
ContRect    dw    0,0,0,0
FrRect      dw    0,0,0,0
InRect      dw    0,0,60,300
InField     dw    19,8,35,292

PfxParms    dw    2
            dw    0                 ; prefix 0
            adrl  FilePath
BootParms   dw    1
            adrl  VolBuf
VolBuf      dw    68                ; buffer size, then a GS/OS string
            ds    66
QuitParms   dw    2
            adrl  0                 ; path
            dw    0                 ; flags ($8000: back here)

OpenParms   dw    3
            dw    0                 ; refNum
            adrl  0                 ; path
            dw    1                 ; access
RWParms     dw    4
            dw    0
            adrl  0                 ; buffer
            adrl  0                 ; count
            adrl  0                 ; transferred
CloseParms  dw    1
            dw    0
EOFParms    dw    2
            dw    0
            adrl  0
GFIParms    dw    7
            adrl  0                 ; path
            dw    0                 ; access
            dw    0                 ; file type (+8)
            adrl  0                 ; aux type
            dw    0                 ; storage type
            ds    8                 ; created
            ds    8                 ; modified (+24: second, minute, hour,
*                                     year, day, month)
CreateParms dw    5
            adrl  0
            dw    $C3               ; access
            dw    $04               ; TXT
            adrl  0
            dw    1                 ; storage: a seedling
DestParms   dw    1
            adrl  0
DirParms    dw    8
            dw    0                 ; refNum
            dw    0                 ; flags
            dw    1                 ; base
            dw    1                 ; displacement
            adrl  NameRes           ; name (out)
            dw    0                 ; entry number
            dw    0                 ; file type (+16)
            adrl  0                 ; EOF (+18)
NameRes     dw    68                ; buffer size, then a GS/OS string
            ds    66

SlotsFile   dw    16
            asc   '9:Launcher.Slots'
FinderPath  dw    15
            asc   '*:System:Finder'

StartStop   dw    0
            dw    $C080             ; 640 mode
            dw    0
            adrl  0
            dw    15
            dw    3,$0300           ; Miscellaneous Tools
            dw    4,$0307           ; QuickDraw II
            dw    5,$0302           ; Desk Manager
            dw    6,$0300           ; Event Manager
            dw    11,$0200          ; Integer Math
            dw    14,$0301          ; Window Manager
            dw    15,$0301          ; Menu Manager
            dw    16,$0301          ; Control Manager
            dw    18,$0201          ; QuickDraw II Auxiliary
            dw    20,$0300          ; LineEdit
            dw    21,$0300          ; Dialog Manager
            dw    22,$0101          ; Scrap Manager
            dw    23,$0301          ; Standard File
            dw    27,$0300          ; Font Manager
            dw    28,$0300          ; List Manager

EventRec    dw    0                 ; what
            adrl  0                 ; message
            adrl  0                 ; when
            dw    0,0               ; where
            dw    0                 ; modifiers
            adrl  0                 ; task data
            adrl  $001FFFFF         ; task mask
            adrl  0
            dw    0                 ; click count
            adrl  0
            adrl  0
            adrl  0
            dw    0,0
EvRec2      dw    0
            adrl  0
            adrl  0
            dw    0,0
            dw    0

Reply       dw    0                 ; good
            dw    0                 ; file type
            adrl  0                 ; aux type
            dw    3                 ; name: a handle
            adrl  0
            dw    3                 ; path: a handle
            adrl  0

WinParms    dw    78
            dw    $80E0             ; title, movable, visible
            adrl  TitleTx
            adrl  0                 ; refCon
            dw    0,0,0,0           ; zoom rectangle
            adrl  0                 ; colour table
            dw    0,0               ; origin
            dw    0,0               ; data size
            dw    200,640           ; max size
            dw    0,0               ; scroll
            dw    0,0               ; page
            adrl  0                 ; info refCon
            dw    0                 ; info height
            adrl  0                 ; frame proc
            adrl  0                 ; info proc
            adrl  ContentProc
            dw    0,0,0,0           ; where (global): set by Layout
            adrl  $FFFFFFFF         ; in front
            adrl  0

InParms     dw    78
            dw    $2020             ; an alert frame, visible
            adrl  0
            adrl  0
            dw    0,0,0,0
            adrl  0
            dw    0,0
            dw    0,0
            dw    0,0
            dw    0,0
            dw    0,0
            adrl  0
            dw    0
            adrl  0
            adrl  0
            adrl  0
            dw    80,170,140,470
            adrl  $FFFFFFFF
            adrl  0

TitleTx     db    12
            asc   ' GSLauncher '
EditTitleTx db    26
            asc   ' GSLauncher: Edit Slots '
            asc   '  '
AskPrompt   db    21
            asc   'Choose an application'

AppleMenu   asc   '>>@\XN1',00
            asc   '--About GSLauncher...\N257V',00
            asc   '.',00
FileMenu    asc   '>>  File  \N2',00
            asc   '--Add App...\N260*Nn',00
            asc   '--Edit Slots\N261*Ee',00
            asc   '--Change Slot...\N262',00
            asc   '--Rename Slot...\N263*Rr',00
            asc   '--Remove Slot\N264',00
            asc   '--Move Left\N265',00
            asc   '--Move Right\N266V',00
            asc   '--Quit to Finder\N256*Qq',00
            asc   '.',00
EditMenu    asc   '>>  Edit  \N3',00
            asc   '--Undo\N250*Zz',00
            asc   '--Cut\N251*Xx',00
            asc   '--Copy\N252*Cc',00
            asc   '--Paste\N253*Vv',00
            asc   '--Clear\N254',00
            asc   '.',00

AboutTx     asc   '63/GSLauncher 1.0'
            db    $0D,$0D
            asc   'Your applications, one click away.'
            db    $0D
            asc   'Click a slot to start its app. Edit Slots (File'
            asc   ' menu) to add, change, rename or move them.'
            db    $0D,$0D
            asc   '2026 Walter Tengler.'
            asc   '/^#0',00
NotFoundA   asc   '43/Cannot find ',00
NotFoundB   asc   '.'
            db    $0D,$0D
            asc   'Choose Edit Slots, click it, then Change Slot.'
            asc   '/^#0',00
NotAppTx    asc   '43/That is not an application GSLauncher can'
            asc   ' start (S16 or SYS files).'
            asc   '/^#0',00
NoFinderTx  asc   '43/Cannot find the Finder (System folder).'
            asc   '/^#0',00
NeedSelTx   asc   '33/Choose Edit Slots in the File menu, then click'
            asc   ' a slot first.'
            asc   '/^#0',00
FullTx      asc   '33/All 18 slots are taken. Remove one first.'
            asc   '/^#0',00
LongTx      asc   '43/That path is too long.'
            asc   '/^#0',00
SaveErrTx   asc   '43/The slots could not be saved'
            asc   ' (Launcher.Slots).'
            asc   '/^#0',00
EmptyTx     asc   'No apps yet.',00
Empty2Tx    asc   'Choose Add App... in the File menu.',00
MissingTx   asc   'not found',00
InQTx       asc   'Name for this slot:',00
InHintTx    asc   'Return: OK     Esc: Cancel',00
CaretTx     asc   '_',00

AppName     ds    66
PatBuf      ds    18
DateTmp     ds    20
InBuf       ds    NameSz+2
MsgBuf      ds    256
LineBuf     ds    LineMax+4
PathBuf     ds    PathSz
ScanPath    ds    PathSz
FilePath    ds    PathSz
SlotType    ds    MaxSlots*2
SlotHas     ds    MaxSlots*2
SlotOK      ds    MaxSlots*2
SlotName    ds    MaxSlots*NameSz
SlotDate    ds    MaxSlots*DateSz
SlotPath    ds    MaxSlots*PathSz
FileBuf     ds    FileMax+4
SlotIcon    ds    MaxSlots*IconMax
