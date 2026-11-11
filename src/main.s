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
            lda   FirstRun
            beq   EventLoop
            jsr   FindApps          ; (the first start: what to add?)
            jsr   SaveSlots         ; (the file is there from now on)

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
DoKey       lda   EventRec+2
            and   #$7F
            cmp   #K_TAB
            bne   :nt
            jmp   NextPage
:nt         cmp   #'1'
            bcc   :ed
            cmp   #'9'+1
            bcs   :ed
            sec                     ; a number: that slot
            sbc   #'1'
            cmp   NSlots
            bcs   :x
            ldx   EditMode
            bne   :pick
            jmp   Launch
:pick       sta   Sel
            jmp   Redraw
:ed         ldx   EditMode
            beq   :x
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
            lda   ClickPt           ; the tabs above the slots
            cmp   TopOff
            bcs   :slots
            lda   TopOff
            beq   :x
            jmp   TabClick
:slots      jsr   HitSlot
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
            sbc   TopOff
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
:app         jsr   CountLaunch
            lda   CurI
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
MakeMenus   PushLong HelpMenu
            jsr   AddMenu
            PushLong EditMenu
            jsr   AddMenu
            PushLong ViewMenu
            jsr   AddMenu
            PushLong PageMenu
            jsr   AddMenu
            PushLong FileMenu
            jsr   AddMenu
            PushLong AppleMenu
            jsr   AddMenu
            pea   1                 ; the Apple menu: desk accessories
            Tool  _FixAppleMenu
            jsr   ViewChecks
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
            da    iHelp1,Help1
            da    iHelp2,Help2
            da    iHelp3,Help3
            da    iHelp4,Help4
            da    iHelp5,Help5
            da    iHelp6,Help6
            da    iFind,FindApps
            da    iNextPg,NextPage
            da    iNewPg,NewPage
            da    iRenPg,RenamePage
            da    iDelPg,RemovePage
            da    iMovPg,MovePage
            da    iViewD,ViewDate
            da    iViewU,ViewUsed
            da    iViewC,ViewCount
            da    iClean,CleanSlots
            da    iRestart,Restart
            da    iShut,ShutDown
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
iHelp1      equ   267
iHelp2      equ   268
iHelp3      equ   269
iHelp4      equ   270
iHelp5      equ   272
iHelp6      equ   273
iFind       equ   271
iNextPg     equ   280
iNewPg      equ   281
iRenPg      equ   282
iDelPg      equ   283
iMovPg      equ   284
iViewD      equ   285
iViewU      equ   286
iViewC      equ   287
iClean      equ   288
iRestart    equ   289
iShut       equ   290

Help1       ldx   #Page1
            jmp   ShowPage
Help2       ldx   #Page2
            jmp   ShowPage
Help3       ldx   #Page3
            jmp   ShowPage
Help4       ldx   #Page4
            jmp   ShowPage
Help5       ldx   #Page5
            jmp   ShowPage
Help6       ldx   #Page6
            jmp   ShowPage

* ShowPage: X = a page: a list of C string addresses, 0 at the end,
* the first is the title. Shown in a window until a click or a key.
ShowPage    stx   SP1
            ldy   #0                ; its lines: the window's height
:n          lda   (SP1),y
            beq   :cnt
            iny
            iny
            bra   :n
:cnt        tya
            lsr
            sta   PageN
            asl                     ; * 12
            clc
            adc   PageN
            asl
            asl
            adc   #20
            sta   T0                ; (a title line, and 2 extra)
            lda   #16
            sta   HelpParms+62
            clc
            adc   T0
            sta   HelpParms+66
            pha
            pha
            PushLong HelpParms
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
            lda   T0
            sta   HelpRect+4
            PushLong HelpRect
            Tool  _EraseRect
            ldy   #0
            lda   #14
            sta   PY
:l          lda   (SP1),y
            beq   :wait0
            phy
            tax
            lda   #12
            sta   PX
            jsr   DrawAt
            ply
            iny
            iny
            lda   PY
            clc
            adc   #12
            sta   PY
            cpy   #2                ; (a gap under the title)
            bne   :l
            adc   #4
            sta   PY
            bra   :l
:wait0      pha                     ; (events from the menu click: gone)
            pea   $FFFF
            pea   0
            Tool  _FlushEvents
            pla
:wait       pha
            pea   $000A             ; a click or a key
            PushLong EvRec2
            Tool  _GetNextEvent
            pla
            beq   :wait
            PushLongAt InWin
            Tool  _CloseWindow
            jmp   UsePort
PagePtr     dw    0
PageN       dw    0
HelpRect    dw    0,0,0,560

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
            jsr   ClearUse
            lda   CurI
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
            jsr   RemoveCore
            jsr   SaveSlots
            jmp   Relayout
:x          rts

* RemoveCore: slot Sel moved to the end, then dropped
RemoveCore  lda   Sel
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
:s          rts

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
            jsr   UsedOf
            pha
            lda   T7
            jsr   UsedOf
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
            cpy   #8
            bcc   :w
            rts
WordArrs    da    SlotType,SlotHas,SlotOK,SlotCount

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
            PushLong InRect
            Tool  _EraseRect
            stz   NBtn              ; Cancel and OK: real buttons
            ldx   #InCanRect
            jsr   :rect
            ldx   #CancelBt
            lda   #2
            ldy   #0
            jsr   NewBtn
            ldx   #InOKRect
            jsr   :rect
            ldx   #OKBt
            lda   #1
            ldy   #1
            jsr   NewBtn
            jsr   DrawBtns
:draw       PushLong InTop
            Tool  _EraseRect
            lda   #10
            sta   PX
            lda   #13
            sta   PY
            ldx   InQP
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
:wait       pha
            pea   $002A             ; keys and clicks
            PushLong EvRec2
            Tool  _GetNextEvent
            pla
            beq   :wait
            lda   EvRec2
            cmp   #1
            bne   :key
            jsr   CtlHit            ; a click: on a button?
            cmp   #1
            bne   :nok
            jmp   :ok
:nok        cmp   #2
            bne   :wait
            jmp   :cancel
:rect       lda   |0,x              ; OnbR = the rectangle at X
            sta   OnbR
            lda   |2,x
            sta   OnbR+2
            lda   |4,x
            sta   OnbR+4
            lda   |6,x
            sta   OnbR+6
            rts
:key        lda   EvRec2+2
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
            bcs   :jx1028_0
            jmp   :wait
:jx1028_0
            cpx   #NameMax
            bcc   :jx1032_0
            jmp   :wait
:jx1032_0
            sta   InBuf,x           ; (and the zero after it)
            jmp   :draw
:rub        cpx   #0
            bne   :jx1038_0
            jmp   :wait
:jx1038_0
            stz   InBuf-1,x         ; (the last one and the zero: a word)
            jmp   :draw
:ok         jsr   :close
            clc
            rts
:cancel     jsr   :close
            sec
            rts
:close      lda   #InQTx
            sta   InQP
            PushLongAt InWin
            Tool  _CloseWindow
            jmp   UsePort

*-------------------------------------------------------------
* The window
*-------------------------------------------------------------
* Layout: columns, rows and the window's size and place for NSlots
Layout      stz   TopOff            ; (tabs above the slots: 2 pages or more)
            lda   NGroups
            cmp   #2
            bcc   :nt
            lda   #TabH
            sta   TopOff
:nt         lda   NSlots
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
            clc
            adc   TopOff
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
            jsr   DrawTabs
            lda   NSlots
            bne   :slots
            lda   #Margin+10        ; none yet: what to do
            sta   PX
            lda   TopOff
            clc
            adc   #Margin+20
            sta   PY
            ldx   #EmptyTx
            jsr   DrawAt
            lda   #Margin+10
            sta   PX
            lda   TopOff
            clc
            adc   #Margin+32
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
            jsr   ThirdLine         ; (file date, last used or launches)
            ldy   #48
            jsr   CellText
            lda   CurI              ; 1-9: the key that starts it
            cmp   #9
            bcs   :nonum
            clc
            adc   #'1'
            sta   DigTx
            lda   CellX
            clc
            adc   #5
            sta   PX
            lda   CellY
            clc
            adc   #11
            sta   PY
            ldx   #DigTx
            jsr   DrawAt
:nonum
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
:cyd        clc
            adc   TopOff
            sta   CellY
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
UsedOf      asl
            asl
            asl
            asl
            clc
            adc   #SlotUsed
            rts
DateOf      asl
            asl
            asl
            asl
            clc
            adc   #SlotDate
            rts
IconOf      xba                     ; * 768
            and   #$FF00
            sta   PO2
            asl
            clc
            adc   PO2
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
*-------------------------------------------------------------
* Pages: the slots are kept in pages (tabs). Master holds the slot
* lines of every page, one after the other; the page on show is in
* the slot arrays, and written back to Master (SerializePage) when
* it is left or saved.
*-------------------------------------------------------------
* NextLine: the next line of the text at SP1 (FPos to FEnd) into
* LineBuf; carry set at the end
NextLine    lda   FPos
            cmp   FEnd
            bcs   :end
            ldy   FPos
            ldx   #0
:c          cpy   FEnd
            bcs   :eol
            lda   (SP1),y
            and   #$FF
            iny
            cmp   #$0D
            beq   :eol
            cmp   #$0A
            beq   :eol
            cpx   #LineMax
            bcs   :c                ; (too long: the rest dropped)
            sta   LineBuf,x         ; (and a zero after it)
            inx
            bra   :c
:eol        sty   FPos
            lda   #0
            sta   LineBuf,x
            clc
            rts
:end        sec
            rts

* LoadSlots: the file into pages (carry: none yet, the first start)
LoadSlots   stz   NSlots
            lda   #1
            sta   NGroups
            stz   CurG
            stz   MLen
            stz   ViewMode
            stz   PageOff
            stz   PageLen
            ldx   #DefPageTx
            ldy   #PageName
            jsr   CopyC
            ldx   #SlotsFile
            lda   #1
            jsr   OpenFile
            bcc   :open
            inc   FirstRun          ; (no slots file: the first start)
            rts
:open       GSOS  _GetEOFGS;EOFParms
            lda   EOFParms+4
            ldx   EOFParms+6
            bne   :max
            cmp   #MasterMax
            bcc   :n
:max        lda   #MasterMax
:n          sta   RWParms+8
            stz   RWParms+10
            stz   RWParms+12
            lda   #LoadBuf
            sta   RWParms+4
            lda   MyBank
            sta   RWParms+6
            GSOS  _ReadGS;RWParms
            lda   RWParms+12
            sta   FileLen
            GSOS  _CloseGS;CloseParms
            jsr   SplitFile
            lda   #0
            jmp   ParsePage

* SplitFile: LoadBuf (FileLen bytes) into Master, page by page
SplitFile   stz   FPos
            lda   FileLen
            sta   FEnd
            stz   WPage
            stz   HdrSeen
            stz   PageLines
:line       lda   #LoadBuf
            sta   SP1
            jsr   NextLine
            bcs   :done
            lda   LineBuf
            and   #$FF
            beq   :line
            cmp   #'#'
            beq   :line
            cmp   #';'
            beq   :line
            cmp   #'@'
            beq   :set
            cmp   #'['
            beq   :hdr
            jsr   AppendLine
            bra   :line
:set        lda   LineBuf+1         ; @view=N
            and   #$FF
            cmp   #'v'
            bne   :line
            lda   LineBuf+6
            and   #$FF
            sec
            sbc   #'0'
            cmp   #3
            bcs   :line
            sta   ViewMode
            bra   :line
:hdr        jsr   NewHeader
            bra   :line
:done       rts

* NewHeader: LineBuf = "[name]": the first names page 0, the others
* start a page (more than MaxGroups: they go on the last)
NewHeader   lda   HdrSeen
            bne   :new
            inc   HdrSeen
            lda   PageLen           ; (page 0 has nothing yet: it is this one)
            bne   :new
            lda   #0
            bra   :name
:new        lda   NGroups
            cmp   #MaxGroups
            bcc   :add
            rts
:add        sta   WPage
            asl
            tax
            lda   MLen
            sta   PageOff,x
            stz   PageLen,x
            lda   NGroups
            inc   NGroups
            stz   PageLines
:name       sta   WPage
            jsr   PageNameAddr
            sta   SP2
            ldx   #1
            ldy   #0
:c          lda   LineBuf,x
            and   #$FF
            beq   :d
            cmp   #']'
            beq   :d
            cpy   #NameMax
            bcs   :d
            sep   #$20
            mx    %10
            sta   (SP2),y
            rep   #$20
            mx    %00
            inx
            iny
            bra   :c
:d          sep   #$20
            mx    %10
            lda   #0
            sta   (SP2),y
            rep   #$20
            mx    %00
            cpy   #0
            bne   :x
            ldx   #DefPageTx        ; (no name: Apps)
            lda   WPage
            jsr   PageNameAddr
            tay
            jsr   CopyC
:x          rts

* PageNameAddr: A = a page: A = the address of its name
PageNameAddr asl
            asl
            asl
            asl
            asl
            clc
            adc   #PageName
            rts

* AppendLine: LineBuf as a line of page WPage (the last one in Master)
AppendLine  lda   PageLines
            cmp   #MaxSlots
            bcs   :x
            ldx   #0
:l          lda   LineBuf,x
            and   #$FF
            beq   :e
            inx
            bra   :l
:e          txa
            clc
            adc   MLen
            inc
            cmp   #MasterMax
            bcs   :x
            ldy   MLen
            sty   T3
            ldx   #0
            sep   #$20
            mx    %10
:c          lda   LineBuf,x
            beq   :d
            sta   Master,y
            inx
            iny
            bra   :c
:d          lda   #$0D
            sta   Master,y
            iny
            rep   #$20
            mx    %00
            sty   MLen
            tya
            sec
            sbc   T3
            sta   T3
            lda   WPage
            asl
            tax
            lda   PageLen,x
            clc
            adc   T3
            sta   PageLen,x
            inc   PageLines
:x          rts

* ParsePage: A = a page: its lines into the slot arrays (NSlots from 0)
ParsePage   asl
            tax
            lda   PageOff,x
            sta   FPos
            clc
            adc   PageLen,x
            sta   FEnd
            stz   NSlots
:line       lda   NSlots
            cmp   #MaxSlots
            bcs   :done
            lda   #Master
            sta   SP1
            jsr   NextLine
            bcs   :done
            lda   LineBuf
            and   #$FF
            beq   :line
            jsr   AddLine
            bra   :line
:done       rts

* SerializePage: the slot arrays as the text of page CurG in Master
SerializePage lda  #LoadBuf
            sta   OPtr
            ldy   #0
            stz   SerI
:s          lda   SerI
            cmp   NSlots
            bcs   :built
            sta   T6
            jsr   BuildLine
            inc   SerI
            bra   :s
:built      lda   CurG
            jmp   ReplacePage       ; (Y: the length)

* BuildLine: slot T6 as a line at (OPtr),Y: name=path|count|last used
BuildLine   lda   T6
            jsr   NameOf
            tax
:n          lda   |0,x
            and   #$FF
            beq   :nd
            sta   (OPtr),y
            inx
            iny
            bra   :n
:nd         lda   #'='
            sta   (OPtr),y
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
            sta   (OPtr),y
            inx
            iny
            dec   T4
            bra   :pc
:pd         lda   T6
            asl
            tax
            lda   SlotCount,x
            beq   :eol
            pha
            lda   #'|'
            sta   (OPtr),y
            iny
            pla
            jsr   PutNum
            lda   #'|'
            sta   (OPtr),y
            iny
            lda   T6
            jsr   UsedOf
            tax
:uc         lda   |0,x
            and   #$FF
            beq   :eol
            sta   (OPtr),y
            inx
            iny
            bra   :uc
:eol        lda   #$0D
            sta   (OPtr),y
            iny
            rts

* PutNum: A = a number as digits at (OPtr),Y
PutNum      stz   T2
:d          ldx   #0
:s          cmp   #10
            bcc   :r
            sbc   #10
            inx
            bra   :s
:r          ora   #'0'
            pha
            inc   T2
            txa
            bne   :d
:p          pla
            sta   (OPtr),y
            iny
            dec   T2
            bne   :p
            rts

* ReplacePage: A = a page, LoadBuf's first Y bytes its new text in
* Master (carry set: no room)
ReplacePage sta   RPg
            sty   RLen
            asl
            tax
            lda   PageLen,x
            sta   ROld
            lda   PageOff,x
            sta   ROff
            lda   MLen
            sec
            sbc   ROld
            clc
            adc   RLen
            cmp   #MasterMax
            bcs   :full
            lda   ROff              ; what follows the page: moved
            clc
            adc   ROld
            sta   RTail
            lda   MLen
            sec
            sbc   RTail
            sta   RTailN
            lda   RTail
            clc
            adc   #Master
            tax
            lda   ROff
            clc
            adc   RLen
            clc
            adc   #Master
            tay
            lda   RTailN
            jsr   MoveMem
            ldx   #LoadBuf          ; the new text in
            lda   ROff
            clc
            adc   #Master
            tay
            lda   RLen
            jsr   MoveMem
            lda   RLen
            sec
            sbc   ROld
            sta   RDelta
            lda   RPg
            asl
            tax
            lda   RLen
            sta   PageLen,x
            ldy   RPg
            iny
:f          cpy   NGroups
            bcs   :fd
            tya
            asl
            tax
            lda   PageOff,x
            clc
            adc   RDelta
            sta   PageOff,x
            iny
            bra   :f
:fd         lda   MLen
            clc
            adc   RDelta
            sta   MLen
            clc
            rts
:full       ldx   #SaveErrTx
            jsr   Alert
            sec
            rts

* MoveMem: A bytes from X to Y (this bank), overlapping or not
MoveMem     sta   T0
            beq   :x
            sep   #$20
            mx    %10
            lda   MyBank
            sta   MvpOp+1
            sta   MvpOp+2
            sta   MvnOp+1
            sta   MvnOp+2
            rep   #$20
            mx    %00
            stx   T1
            sty   T2
            lda   T2
            cmp   T1
            beq   :x
            bcc   :fwd
            lda   T1                ; to a higher place: from the end
            clc
            adc   T0
            dec
            tax
            lda   T2
            clc
            adc   T0
            dec
            tay
            lda   T0
            dec
            jsr   MvpOp
            rts
:fwd        ldx   T1
            ldy   T2
            lda   T0
            dec
            jsr   MvnOp
:x          rts
MvpOp       db    $44,0,0
            rts
MvnOp       db    $54,0,0
            rts

* SaveSlots: the file written again
SaveSlots   jsr   SerializePage
            bcc   :ok
            rts
:ok         jsr   ComposeFile
            sty   FileLen
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
            lda   #LoadBuf
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

* ComposeFile: LoadBuf = the whole file; Y = its length
ComposeFile lda   #LoadBuf
            sta   OPtr
            ldy   #0
            lda   #'@'
            sta   (OPtr),y
            iny
            ldx   #ViewKey
:v          lda   |0,x
            and   #$FF
            beq   :vd
            sta   (OPtr),y
            inx
            iny
            bra   :v
:vd         lda   ViewMode
            ora   #'0'
            sta   (OPtr),y
            iny
            lda   #$0D
            sta   (OPtr),y
            iny
            sty   CIdx
            stz   RPg
:g          lda   RPg
            cmp   NGroups
            bcs   :done
            ldy   CIdx
            lda   #'['
            sta   (OPtr),y
            iny
            lda   RPg
            jsr   PageNameAddr
            tax
:nc         lda   |0,x
            and   #$FF
            beq   :nd
            sta   (OPtr),y
            inx
            iny
            bra   :nc
:nd         lda   #']'
            sta   (OPtr),y
            iny
            lda   #$0D
            sta   (OPtr),y
            iny
            sty   CIdx
            lda   RPg
            asl
            tax
            lda   PageOff,x
            clc
            adc   #Master
            sta   T4
            lda   PageLen,x
            sta   T5
            lda   CIdx
            clc
            adc   #LoadBuf
            tay
            ldx   T4
            lda   T5
            jsr   MoveMem
            lda   T5
            clc
            adc   CIdx
            sta   CIdx
            inc   RPg
            bra   :g
:done       ldy   CIdx
            rts
ViewKey     asc   'view=',00

* CountLines: A = a page: how many lines it has
CountLines  asl
            tax
            lda   PageOff,x
            tay
            clc
            adc   PageLen,x
            sta   T3
            stz   T4
:l          cpy   T3
            bcs   :x
            lda   Master,y
            and   #$FF
            iny
            cmp   #$0D
            bne   :l
            inc   T4
            bra   :l
:x          lda   T4
            rts

* SwitchPage: A = a page: shown
SwitchPage  cmp   CurG
            beq   :x
            pha
            jsr   SerializePage
            pla
            sta   CurG
            jmp   LoadPageNow
:x          rts

* LoadPageNow: page CurG from Master into the arrays, shown
LoadPageNow Tool  _WaitCursor
            lda   CurG
            jsr   ParsePage
            jsr   ScanAll
            Tool  _InitCursor
            lda   #$FFFF
            sta   Sel
            jmp   Relayout

NextPage    lda   NGroups
            cmp   #2
            bcc   :x
            lda   CurG
            inc
            cmp   NGroups
            bcc   :s
            lda   #0
:s          jmp   SwitchPage
:x          rts

NewPage     lda   NGroups
            cmp   #MaxGroups
            bcc   :ok
            ldx   #MaxPgTx
            jmp   Alert
:ok         stz   InBuf
            lda   #PageQTx
            sta   InQP
            jsr   InputBox
            bcs   :x
            lda   InBuf
            and   #$FF
            beq   :x
            jsr   SerializePage
            lda   NGroups
            asl
            tax
            lda   MLen
            sta   PageOff,x
            stz   PageLen,x
            lda   NGroups
            jsr   PageNameAddr
            tay
            ldx   #InBuf
            jsr   CopyC
            inc   NGroups
            lda   NGroups
            dec
            sta   CurG
            jsr   LoadPageNow
            jmp   SaveSlots
:x          rts

RenamePage  lda   CurG
            jsr   PageNameAddr
            tax
            ldy   #InBuf
            jsr   CopyC
            lda   #PageQTx
            sta   InQP
            jsr   InputBox
            bcs   :x
            lda   InBuf
            and   #$FF
            beq   :x
            lda   CurG
            jsr   PageNameAddr
            tay
            ldx   #InBuf
            jsr   CopyC
            jsr   SaveSlots
            jmp   Redraw
:x          rts

* RemovePage: the page and its slots (not the apps) go
RemovePage  lda   NGroups
            cmp   #2
            bcs   :ok
            ldx   #OnePgTx
            jmp   Alert
:ok         ldx   #DelPgTx
            jsr   Confirm
            bcs   :x
            lda   CurG              ; its text out of Master
            ldy   #0
            jsr   ReplacePage
            lda   CurG
            sta   T6
:m          lda   T6
            inc
            cmp   NGroups
            bcs   :md
            sta   T7
            lda   T6
            jsr   PageNameAddr
            tay
            lda   T7
            jsr   PageNameAddr
            tax
            jsr   CopyC
            lda   T6
            asl
            tax
            lda   PageOff+2,x
            sta   PageOff,x
            lda   PageLen+2,x
            sta   PageLen,x
            inc   T6
            bra   :m
:md         dec   NGroups
            lda   CurG
            cmp   NGroups
            bcc   :s
            lda   NGroups
            dec
            sta   CurG
:s          jsr   LoadPageNow
            jmp   SaveSlots
:x          rts

* MovePage: the slot chosen goes to the end of the next page
MovePage    lda   NGroups
            cmp   #2
            bcs   :ok
            ldx   #OnePgTx
            jmp   Alert
:ok         jsr   NeedSel
            bcs   :x
            lda   CurG
            inc
            cmp   NGroups
            bcc   :t
            lda   #0
:t          sta   MoveTo
            jsr   CountLines
            cmp   #MaxSlots
            bcc   :room
            ldx   #FullTx
            jmp   Alert
:room       lda   #XLine            ; the slot as a line
            sta   OPtr
            ldy   #0
            lda   Sel
            sta   T6
            jsr   BuildLine
            sty   XLen
            jsr   RemoveCore
            jsr   SerializePage
            lda   MoveTo            ; the next page's text and the line
            asl
            tax
            lda   PageOff,x
            clc
            adc   #Master
            tax
            lda   MoveTo
            asl
            tay
            lda   PageLen,y
            sta   T5
            ldy   #LoadBuf
            lda   T5
            jsr   MoveMem
            ldx   #XLine
            lda   T5
            clc
            adc   #LoadBuf
            tay
            lda   XLen
            jsr   MoveMem
            lda   T5
            clc
            adc   XLen
            tay
            lda   MoveTo
            jsr   ReplacePage
            jsr   SaveSlots
            jmp   Relayout
:x          rts

* RemoveMissing: the slots (on this page) whose apps are gone
CleanSlots  stz   AddN
            stz   T6
:l          lda   T6
            cmp   NSlots
            bcs   :done
            asl
            tax
            lda   SlotOK,x
            bne   :next
            lda   T6
            sta   Sel
            jsr   RemoveCore
            inc   AddN
            bra   :l
:next       inc   T6
            bra   :l
:done       lda   AddN
            bne   :some
            ldx   #NoMissTx
            jmp   Alert
:some       lda   #$FFFF
            sta   Sel
            jsr   SaveSlots
            jmp   Relayout

* ClearUse: A = a slot: no launches yet
ClearUse    sta   T0
            asl
            tax
            stz   SlotCount,x
            lda   T0
            jsr   UsedOf
            tax
            stz   |0,x
            rts

* CountLaunch: slot CurI launched: its count up, its time (the slots
* file's own time once it is written) saved
CountLaunch lda   CurI
            asl
            tax
            lda   SlotCount,x
            cmp   #9999
            bcs   :s
            inc
            sta   SlotCount,x
:s          jsr   SaveSlots
            lda   #SlotsFile
            ldx   #GFIParms
            jsr   SetPath
            GSOS  _GetFileInfoGS;GFIParms
            bcs   :x
            jsr   DateFmt
            lda   CurI
            jsr   UsedOf
            tay
            ldx   #DateTmp
            jsr   CopyC
            jmp   SaveSlots
:x          rts

* Views: what the third line of a slot shows
ViewDate    lda   #0
            bra   SetView
ViewUsed    lda   #1
            bra   SetView
ViewCount   lda   #2
SetView     sta   ViewMode
            jsr   ViewChecks
            jsr   SaveSlots
            jmp   Redraw
ViewChecks  stz   T6
:l          lda   T6
            cmp   ViewMode
            beq   :on
            lda   #0
            bra   :c
:on         lda   #1
:c          pha
            lda   T6
            clc
            adc   #iViewD
            pha
            Tool  _CheckMItem
            inc   T6
            lda   T6
            cmp   #3
            bcc   :l
            rts

* ThirdLine: X = the text for the third line of slot CurI
ThirdLine   lda   ViewMode
            beq   :d
            cmp   #1
            beq   :u
            lda   CurI
            asl
            tax
            lda   SlotCount,x
            bne   :c
            ldx   #NeverTx
            rts
:c          sta   T0
            stz   MsgBuf
            jsr   MsgNum
            lda   T0
            cmp   #1
            bne   :pl
            ldx   #LaunchTx
            bra   :cat
:pl         ldx   #LaunchesTx
:cat        jsr   MsgCat
            ldx   #MsgBuf
            rts
:u          lda   CurI
            jsr   UsedOf
            tax
            lda   |0,x
            and   #$FF
            bne   :r
            ldx   #NotUsedTx
:r          rts
:d          lda   CurI
            jsr   DateOf
            tax
            rts

* DrawTabs: the page names across the top of the window (2 or more)
DrawTabs    lda   NGroups
            cmp   #2
            bcs   :jx2480_0
            jmp   :x
:jx2480_0
            pea   1
            pea   1
            Tool  _SetPenSize
            pea   0
            Tool  _SetSolidPenPat
            stz   DrawG
:l          lda   DrawG             ; its tab: 90 wide
            asl
            sta   T0
            asl
            asl
            asl
            clc
            adc   T0
            sta   T1
            lda   DrawG
            asl
            tax
            lda   TabX,x
            sta   FrRect+2
            lda   #1
            sta   FrRect
            lda   #TabH-1
            sta   FrRect+4
            lda   FrRect+2
            clc
            adc   #TabW-4
            sta   FrRect+6
            PushLong FrRect
            Tool  _FrameRect
            lda   DrawG
            cmp   CurG
            bne   :txt
            PushLong FrRect         ; the page shown: black, white text
            Tool  _PaintRect
            pea   $000F
            Tool  _SetForeColor
            pea   $0000
            Tool  _SetBackColor
:txt            lda   DrawG
            jsr   PageNameAddr
            tax
            ldy   #0                ; (12 letters at most)
            stz   T0
            sep   #$20
            mx    %10
:nc         lda   |0,x
            beq   :nd
            cpy   #12
            bcs   :nd
            sta   MsgBuf,y
            inx
            iny
            bra   :nc
:nd         lda   #0
            sta   MsgBuf,y
            rep   #$20
            mx    %00
            lda   FrRect+2
            clc
            adc   #6
            sta   PX
            lda   #TabH-6
            sta   PY
            ldx   #MsgBuf
            jsr   DrawAt
            pea   $0000
            Tool  _SetForeColor
            pea   $000F
            Tool  _SetBackColor
            inc   DrawG
            lda   DrawG
            cmp   NGroups
            bcs   :jx2556_0
            jmp   :l
:jx2556_0
:x          rts
TabX        dw    2,92,182,272

* TabClick: ClickPt is in the tab strip: that page shown
TabClick    lda   ClickPt+2
            ldx   #0
:d          cmp   #TabW
            bcc   :r
            sbc   #TabW
            inx
            bra   :d
:r          cpx   NGroups
            bcs   :x
            txa
            jmp   SwitchPage
:x          rts

* Confirm: X = an alert string with two buttons: carry clear for the
* first one
Confirm     pha
            pea   0
            PushLong 0
            pea   ^AboutTx
            phx
            Tool  _AlertWindow
            pla
            cmp   #0                ; (the first button is 0)
            beq   :ok
            sec
            rts
:ok         clc
            rts

* Restart, ShutDown: GS/OS OSShutdown (the only way that is allowed)
Restart     ldx   #RestartQTx
            jsr   Confirm
            bcs   :x
            lda   #1
            bra   OsShut
:x          rts
ShutDown    ldx   #ShutQTx
            jsr   Confirm
            bcs   :y
            lda   #0
OsShut      sta   ShutParms+2
            GSOS  _OSShutdownGS;ShutParms
            ldx   #ShutErrTx
            jmp   Alert
:y          rts

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
            jsr   ClearUse
            lda   NSlots
            jsr   PathOf
            sta   SP2
            ldx   T4
            ldy   #2
:pc         lda   LineBuf,x
            and   #$FF
            beq   :pe
            cmp   #'|'
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
:pe         stx   T6                ; (where the path ended)
            dey
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
:named      jsr   ParseExtras
            inc   NSlots
:x          rts

* ParseExtras: after the path in LineBuf (T6 its end): |count|last used
ParseExtras ldx   T6
            lda   LineBuf,x
            and   #$FF
            cmp   #'|'
            bne   :x
            inx
            stz   T3
:d          lda   LineBuf,x
            and   #$FF
            sec
            sbc   #'0'
            cmp   #10
            bcs   :dn
            sta   T4
            lda   T3
            asl
            sta   T5
            asl
            asl
            clc
            adc   T5
            clc
            adc   T4
            sta   T3
            inx
            bra   :d
:dn         lda   NSlots
            asl
            tay
            lda   T3
            sta   SlotCount,y
            lda   LineBuf,x
            and   #$FF
            cmp   #'|'
            bne   :x
            inx
            lda   NSlots
            jsr   UsedOf
            sta   SP2
            ldy   #0
:u          lda   LineBuf,x
            and   #$FF
            beq   :ud
            cpy   #DateSz-1
            bcs   :ud
            sep   #$20
            mx    %10
            sta   (SP2),y
            rep   #$20
            mx    %00
            inx
            iny
            bra   :u
:ud         sep   #$20
            mx    %10
            lda   #0
            sta   (SP2),y
            rep   #$20
            mx    %00
:x          rts

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
            jsr   DateFmt
            lda   CurI
            jsr   DateOf
            tay
            ldx   #DateTmp
            jmp   CopyC

* DateFmt: DateTmp = the modified date and time in GFIParms as "04 Nov 10:22"
DateFmt
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
            rts
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

*-------------------------------------------------------------
* Find Apps: looks on the disks for applications (S16 and SYS)
* and lists them with check boxes; the ones checked become slots.
* Two steps in one window: which disks, then which apps.
*-------------------------------------------------------------
FindApps    jsr   ListVols
            stz   NFound
            stz   OState
            stz   OTop
            jsr   OnbOpen
            jsr   MakeBtns
:draw       jsr   OnbDraw
:wait       pha
            pea   $000A             ; clicks and keys
            PushLong EvRec2
            Tool  _GetNextEvent
            pla
            beq   :wait
            lda   EvRec2
            cmp   #evKeyDown
            beq   :key
            jsr   OnbClick          ; A: a button's number, $FF redraw, 0 none
            bra   :act
:key        jsr   OnbKey
:act        cmp   #0
            beq   :wait
            cmp   #$FF
            beq   :draw
            cmp   #1
            bne   :n2
            lda   OState            ; Scan
            bne   :wait
            jsr   DoScan
            jsr   MakeBtns
            jmp   :draw
:n2         cmp   #2
            bne   :n3
            lda   #1                ; All
            jsr   SelAll
            bra   :draw
:n3         cmp   #3
            bne   :n4
            lda   #0                ; None
            jsr   SelAll
            bra   :draw
:n4         cmp   #4
            bne   :n5
            jmp   OnbClose          ; Cancel
:n5         cmp   #5
            bne   :n6
            lda   OState            ; Add Selected
            beq   :wait
            jsr   OnbClose
            jmp   AddSelected
:n6         jsr   OnbScroll         ; the scroll bar and the arrow keys
            jsr   OnbDrawList
            jmp   :wait

OnbOpen     pha
            pha
            PushLong OnbParms
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
            pea   1
            pea   1
            Tool  _SetPenSize
            pea   0
            Tool  _SetSolidPenPat
            rts

OnbClose    PushLongAt InWin
            Tool  _CloseWindow
            jmp   UsePort

* OnbKey: the key in EvRec2: A = the button it stands for, or 0
OnbKey      lda   EvRec2+2
            and   #$7F
            cmp   #K_ESC
            bne   :r
            lda   #4
            rts
:r          cmp   #K_RETURN
            beq   :ret
            cmp   #3
            bne   :u
:ret        lda   OState            ; Scan, or Add Selected
            beq   :s
            lda   #5
            rts
:s          lda   #1
            rts
:u          cmp   #K_UP
            bne   :d
            lda   #6
            rts
:d          cmp   #K_DOWN
            bne   :pl
            lda   #7
            rts
:pl         cmp   #K_LEFT
            bne   :pr
            lda   #8
            rts
:pr         cmp   #K_RIGHT
            bne   :n
            lda   #9
            rts
:n          lda   #0
            rts

* OnbClick: the click in EvRec2: A = a button's number, $FF if a check
* box changed, 0 if nothing
OnbClick    lda   EvRec2+10
            sta   ClickPt
            lda   EvRec2+12
            sta   ClickPt+2
            PushLong ClickPt
            Tool  _GlobalToLocal
            jsr   CtlHit            ; a button?
            beq   :list
            rts
:list       lda   ClickPt
            sta   T7                ; (where, down the window)
            lda   ClickPt+2
            cmp   #SbL
            bcc   :inlist
            cmp   #SbR+1
            bcs   :none
            jmp   ScrollClick
:inlist     lda   T7
            sec
            sbc   #OListTop
            bcc   :none
            ldx   #0                ; its row: / 12
:d          cmp   #12
            bcc   :r
            sbc   #12
            inx
            bra   :d
:r          cpx   #RowsOnb
            bcs   :none
            txa
            clc
            adc   OTop
            sta   T0
            jsr   GetCount
            cmp   T0
            beq   :none
            bcc   :none
            jsr   SelWord           ; the box: the other way
            lda   |0,x
            eor   #1
            sta   |0,x
            lda   #$FF
            rts
:none       lda   #0
            rts

* GetCount: A = how many are in the list
GetCount    lda   OState
            beq   :v
            lda   NFound
            rts
:v          lda   NVols
            rts

* SelWord: X = the address of the check box word of item T0
SelWord     ldx   #VolSel
            lda   OState
            beq   :a
            ldx   #FoundSel
:a          stx   T1
            lda   T0
            asl
            clc
            adc   T1
            tax
            rts

* SelAll: A = 0 or 1 for every item
SelAll      sta   T2
            stz   T0
:l          jsr   GetCount
            cmp   T0
            beq   :x
            bcc   :x
            jsr   SelWord
            lda   T2
            sta   |0,x
            inc   T0
            bra   :l
:x          rts

* OnbScroll: A = 6 (up) or 7 (down): the list a page (4) on
OnbScroll   sta   T1
            jsr   MaxTop
            sta   T2
            lda   T1
            cmp   #8
            bcs   :page
            lda   #1
            bra   :go
:page       lda   #RowsOnb-1
:go         sta   T3
            lda   T1
            and   #1                ; (even: up, odd: down)
            bne   :down
            lda   OTop
            sec
            sbc   T3
            bcs   :set
            lda   #0
            bra   :set
:down       lda   OTop
            clc
            adc   T3
            cmp   T2
            bcc   :set
            lda   T2
:set        sta   OTop
            rts

* MaxTop: A = the highest OTop (the count less the rows, or 0)
MaxTop      jsr   GetCount
            sec
            sbc   #RowsOnb
            bcs   :x
            lda   #0
:x          rts

* MulDiv: A * X / Y (all small)
MulDiv      sta   T3
            stx   T4
            sty   T5
            lda   #0
:m          ldx   T4
            beq   :md
            clc
            adc   T3
            dec   T4
            bra   :m
:md         ldx   #0
:d          cmp   T5
            bcc   :r
            sbc   T5
            inx
            bra   :d
:r          txa
            rts

* ThumbCalc: where the scroll bar's thumb is (SbThumbTop, SbThumbH)
ThumbCalc   jsr   GetCount
            sta   T0
            lda   #TrackH
            ldx   #RowsOnb
            ldy   T0
            jsr   MulDiv
            cmp   #8
            bcs   :h
            lda   #8
:h          sta   SbThumbH
            lda   #TrackH
            sec
            sbc   SbThumbH
            sta   SbTravel
            lda   T0
            sec
            sbc   #RowsOnb
            tay
            lda   SbTravel
            ldx   OTop
            jsr   MulDiv
            clc
            adc   #SbT+ArrowH
            sta   SbThumbTop
            rts

* DrawScroll: the scroll bar beside the list (when it is longer than
* the window shows)
DrawScroll  jsr   GetCount
            cmp   #RowsOnb+1
            bcs   :go
            rts
:go         jsr   ThumbCalc
            lda   #SbT
            sta   OnbR
            lda   #SbL
            sta   OnbR+2
            lda   #SbB
            sta   OnbR+4
            lda   #SbR
            sta   OnbR+6
            PushLong OnbR
            Tool  _FrameRect
            lda   #SbT+ArrowH       ; the two arrow boxes
            sta   OnbR+4
            PushLong OnbR
            Tool  _FrameRect
            lda   #SbB-ArrowH
            sta   OnbR
            lda   #SbB
            sta   OnbR+4
            PushLong OnbR
            Tool  _FrameRect
            lda   SbThumbTop        ; the thumb
            sta   OnbR
            clc
            adc   SbThumbH
            sta   OnbR+4
            lda   #SbL+2
            sta   OnbR+2
            lda   #SbR-2
            sta   OnbR+6
            PushLong OnbR
            Tool  _PaintRect
            lda   #SbT+4
            ldx   #0
            jsr   DrawArrow
            lda   #SbB-ArrowH+4
            ldx   #1
            jmp   DrawArrow

* DrawArrow: a small triangle from row A down: X = 0 pointing up, 1 down
DrawArrow   sta   T6
            stx   T7
            stz   T5
:l          lda   T6
            sta   OnbR
            clc
            adc   #2
            sta   OnbR+4
            lda   T7
            bne   :dn
            lda   #SbCx-1
            sec
            sbc   T5
            sta   OnbR+2
            lda   #SbCx+2
            clc
            adc   T5
            sta   OnbR+6
            bra   :p
:dn         lda   #SbCx-4
            clc
            adc   T5
            sta   OnbR+2
            lda   #SbCx+5
            sec
            sbc   T5
            sta   OnbR+6
:p          PushLong OnbR
            Tool  _PaintRect
            lda   T6
            clc
            adc   #2
            sta   T6
            inc   T5
            lda   T5
            cmp   #4
            bcc   :l
            rts

* ScrollClick: a click on the scroll bar (T7 = where, down the window):
* A = 6 up a row, 7 down a row, 8 up a page, 9 down a page; the thumb is
* dragged here, and 0 comes back
ScrollClick jsr   GetCount
            cmp   #RowsOnb+1
            bcs   :s
            lda   #0
            rts
:s          jsr   ThumbCalc
            lda   T7
            cmp   #SbB
            bcs   :none
            cmp   #SbB-ArrowH
            bcs   :down
            cmp   #SbT+ArrowH
            bcc   :up
            cmp   SbThumbTop
            bcc   :pgup
            lda   SbThumbTop
            clc
            adc   SbThumbH
            cmp   T7
            bcc   :pgdn
            beq   :pgdn
            jsr   ThumbDrag
:none       lda   #0
            rts
:up         lda   #6
            rts
:down       lda   #7
            rts
:pgup       lda   #8
            rts
:pgdn       lda   #9
            rts

* ThumbDrag: the thumb followed with the pointer until the button is up
ThumbDrag   lda   T7
            sec
            sbc   SbThumbTop
            sta   DragOff
:l          pha
            pea   0
            Tool  _Button
            pla
            beq   :x
            PushLong MousePt
            Tool  _GetMouse
            lda   MousePt
            sec
            sbc   DragOff
            sec
            sbc   #SbT+ArrowH
            bcs   :pos
            lda   #0
:pos        cmp   SbTravel
            bcc   :ok
            lda   SbTravel
:ok         sta   DragPos
            jsr   MaxTop
            tax
            lda   DragPos
            ldy   SbTravel
            jsr   MulDiv
            cmp   OTop
            beq   :l
            sta   OTop
            jsr   OnbDrawList
            bra   :l
:x          rts

* OnbDraw: the window: title, rows with check boxes, line, buttons
OnbDraw     PushLong OnbRect
            Tool  _EraseRect
            ldx   #TitleVTx
            ldy   #SubVTx
            lda   OState
            beq   :t
            ldx   #TitleFTx
            ldy   #SubFTx
:t          phy
            lda   #12
            sta   PX
            lda   #14
            sta   PY
            jsr   DrawAt
            plx
            lda   #28
            sta   PY
            jsr   DrawAt
            jsr   OnbRows
            jsr   DrawInfoLn
            jmp   DrawBtns

* OnbDrawList: just the list and its scroll bar drawn again
OnbDrawList PushLong ListRect
            Tool  _EraseRect

* OnbRows: the rows that are in view, and the scroll bar
OnbRows     stz   RowI
:r          lda   RowI
            cmp   #RowsOnb
            bcs   :done
            clc
            adc   OTop
            sta   RowIdx
            sta   T0
            jsr   GetCount
            cmp   T0
            beq   :done
            bcc   :done
            jsr   DrawRow
            inc   RowI
            bra   :r
:done       jmp   DrawScroll

DrawRow     lda   RowI              ; its top: 36 + 12 a row
            asl
            asl
            sta   T5
            asl
            clc
            adc   T5
            adc   #OListTop
            sta   RowY
            inc
            sta   OnbR              ; the check box
            lda   #12
            sta   OnbR+2
            lda   RowY
            clc
            adc   #11
            sta   OnbR+4
            lda   #22
            sta   OnbR+6
            PushLong OnbR
            Tool  _FrameRect
            lda   RowIdx
            sta   T0
            jsr   SelWord
            lda   |0,x
            beq   :text
            lda   RowY              ; checked: a square in it
            clc
            adc   #3
            sta   OnbR
            lda   #14
            sta   OnbR+2
            lda   RowY
            clc
            adc   #9
            sta   OnbR+4
            lda   #20
            sta   OnbR+6
            PushLong OnbR
            Tool  _PaintRect
:text       jsr   RowText
            lda   #30
            sta   PX
            lda   RowY
            clc
            adc   #10
            sta   PY
            ldx   #MsgBuf
            jmp   DrawAt

* RowText: MsgBuf = the text of item RowIdx
RowText     lda   OState
            bne   :app
            lda   RowIdx            ; a disk: its name (after the ':')
            jsr   VolAddr
            sta   SP1
            lda   (SP1)
            inc
            inc
            sta   T3
            ldx   #0
            ldy   #3
:vc         cpy   T3
            bcs   :vd
            lda   (SP1),y
            sep   #$20
            mx    %10
            sta   MsgBuf,x
            rep   #$20
            mx    %00
            inx
            iny
            bra   :vc
:vd         lda   #0
            sta   MsgBuf,x
            lda   RowIdx
            cmp   BootIdx
            bne   :x
            ldx   #BootTx
            jmp   MsgCat
:x          rts
:app        lda   RowIdx            ; an app: the end of its path
            jsr   FoundPtr
            lda   [Ptr]
            sta   T3
            ldy   #0
            lda   T3
            cmp   #68
            bcc   :ac
            sec                     ; (too long: the last 68)
            sbc   #68
            tay
:ac         ldx   #0
:al         cpy   T3
            bcs   :ad
            phy
            iny
            iny
            lda   [Ptr],y
            ply
            sep   #$20
            mx    %10
            sta   MsgBuf,x
            rep   #$20
            mx    %00
            inx
            iny
            bra   :al
:ad         lda   #0
            sta   MsgBuf,x
            rts

* DrawInfoLn: the line under the list
DrawInfoLn  ldx   #MsgBuf
            lda   OState
            bne   :f
            ldx   #InfoVTx
            bra   :go
:f          lda   NFound
            bne   :some
            ldx   #NoneTx
            bra   :go
:some       ldx   #MsgBuf
            stz   MsgBuf
            lda   NFound
            jsr   MsgNum
            ldx   #FoundTx
            jsr   MsgCat
            lda   NFound
            cmp   #MaxFound
            bcc   :go2
            ldx   #FullListTx
            jsr   MsgCat
:go2        ldx   #MsgBuf
:go         stx   BtnX
            lda   #12
            sta   PX
            lda   #OInfoY
            sta   PY
            ldx   BtnX
            jmp   DrawAt

* MsgNum: A = a number onto the end of MsgBuf
MsgNum      stz   T6
:d          ldx   #0
:s          cmp   #10
            bcc   :r
            sbc   #10
            inx
            bra   :s
:r          ora   #'0'
            pha
            inc   T6
            txa
            bne   :d
:p          pla
            jsr   MsgChr
            dec   T6
            bne   :p
            rts

* MsgChr: A = a character onto the end of MsgBuf
MsgChr      and   #$FF
            sta   T5
            ldx   #0
:e          lda   MsgBuf,x
            and   #$FF
            beq   :a
            inx
            bra   :e
:a          lda   T5
            sta   MsgBuf,x
            rts

* MakeBtns: the window's buttons made again for OState (real buttons:
* Control Manager controls, their handles in BtnH)
MakeBtns    PushLongAt InWin
            Tool  _KillControls
            stz   NBtn
            ldx   #Btns0
            lda   OState
            beq   :b
            ldx   #Btns1
:b          lda   |0,x
            cmp   #$FFFF
            beq   :x
            stx   BtnX
            sta   OnbR+2
            lda   |2,x
            sta   OnbR+6
            lda   #OBtnTop+3
            sta   OnbR
            lda   #OBtnTop+16
            sta   OnbR+4
            lda   |4,x              ; its title
            pha
            lda   |6,x              ; what it does
            pha
            ldy   #0                ; (Scan and Add Selected: the default button)
            cmp   #1
            beq   :def
            cmp   #5
            bne   :mk
:def        ldy   #1
:mk         pla
            plx
            jsr   NewBtn
            lda   BtnX
            clc
            adc   #8
            tax
            bra   :b
:x          rts

* NewBtn: a button in the window InWin: OnbR its rectangle, X its title
* (a Pascal string), A what it does, Y = 1 for the default button
NewBtn      sta   T0
            sty   T1
            stx   T2
            lda   NBtn
            asl
            tax
            lda   T0
            sta   BtnCode,x
            pha                     ; result: the control's handle
            pha
            PushLongAt InWin
            PushLong OnbR
            pea   ^OKBt
            lda   T2
            pha
            lda   T1                ; flag: 0 a button, 1 the default one
            pha
            pea   0                 ; value
            pea   0                 ; param1
            pea   0                 ; param2
            PushLong 0              ; the simple button
            PushLong 0              ; refCon
            PushLong 0              ; colours
            Tool  _NewControl
            lda   NBtn
            asl
            asl
            tax
            pla
            sta   BtnH,x
            pla
            sta   BtnH+2,x
            inc   NBtn
            rts

DrawBtns    PushLongAt InWin
            Tool  _DrawControls
            rts

* CtlHit: the click in EvRec2 on a button of InWin? It is tracked; A =
* what the button does (0: none, or let go outside it)
CtlHit      pha                     ; result: the part
            PushLong HitCtl
            lda   EvRec2+12         ; x, y (global)
            pha
            lda   EvRec2+10
            pha
            PushLongAt InWin
            Tool  _FindControl
            pla
            beq   :none
            pha                     ; result: the part
            lda   EvRec2+12
            pha
            lda   EvRec2+10
            pha
            PushLong 0              ; no action procedure
            PushLongAt HitCtl
            Tool  _TrackControl
            pla
            beq   :none
            ldx   #0                ; which one?
            ldy   #0
:f          cpy   NBtn
            bcs   :none
            lda   BtnH,x
            cmp   HitCtl
            bne   :n
            lda   BtnH+2,x
            cmp   HitCtl+2
            beq   :got
:n          inx
            inx
            inx
            inx
            iny
            bra   :f
:got        tya
            asl
            tax
            lda   BtnCode,x
            rts
:none       lda   #0
            rts

* FoundPtr: A = a found app: Ptr = its record in the 64K buffer
FoundPtr    sta   T0
            xba
            and   #$FF00
            sta   T1
            lda   T0
            asl
            asl
            clc
            adc   T1
            clc
            adc   IPtr
            sta   Ptr
            lda   IPtr+2
            adc   #0
            sta   Ptr+2
            rts

* VolAddr: A = a disk: the address of its record (36 bytes)
VolAddr     sta   T1
            asl
            asl
            sta   T0
            lda   T1
            asl
            asl
            asl
            asl
            asl
            clc
            adc   T0
            adc   #VolRec
            rts

*-------------------------------------------------------------
* The disks
*-------------------------------------------------------------
ListVols    stz   NVols
            lda   #$FFFF
            sta   BootIdx
            jsr   GetBoot
            lda   #1
            sta   DInfoNum
:dl         GSOS  _DInfoGS;DInfoP
            bcc   :have
            cmp   #$11
            beq   :x
            bra   :next
:have       jsr   DevOnline
            bcc   :next
            lda   #DevLen
            sta   VolDev
            lda   MyBank
            sta   VolDev+2
            GSOS  _VolumeGS;VolP
            bcs   :next
            jsr   AddVol
:next       inc   DInfoNum
            lda   DInfoNum
            cmp   #64
            bcc   :dl
:x          rts

* DevOnline: carry set if device DInfoNum is a block device with a
* disk in it (DStatus: no waiting on empty drives)
DevOnline   lda   DInfoChar
            and   #$0080
            beq   :no
            lda   DInfoNum
            sta   DStNum
            GSOS  _DStatusGS;DStP
            bcs   :no
            lda   DStWord
            and   #$0010
            beq   :no
            sec
            rts
:no         clc
            rts

* AddVol: the volume just read (VolNmLen) onto the list; the boot disk
* is checked
AddVol      lda   NVols
            cmp   #MaxVols
            bcs   :x
            lda   VolNmLen
            cmp   #33
            bcs   :x
            lda   NVols
            jsr   VolAddr
            tay
            ldx   #VolNmLen
            jsr   CopyGS
            lda   NVols
            jsr   VolAddr
            tax
            jsr   IsBootRec
            php
            lda   NVols
            asl
            tax
            stz   VolSel,x
            plp
            bcc   :n
            lda   NVols
            sta   BootIdx
            lda   #1
            sta   VolSel,x
:n          inc   NVols
:x          rts

* GetBoot: BootStr = the boot disk's name as ":NAME", BootLen its length
GetBoot     stz   BootLen
            stz   BootStr
            GSOS  _GetBootVolGS;BootParms
            bcs   :x
            lda   VolBuf+2
            sta   T3
            ldx   #0
            lda   VolBuf+4
            and   #$FF
            cmp   #':'
            beq   :c0
            sep   #$20
            mx    %10
            lda   #':'
            sta   BootStr+2
            rep   #$20
            mx    %00
            ldx   #1
:c0         ldy   #0
            sep   #$20
            mx    %10
:c          cpy   T3
            bcs   :d
            lda   VolBuf+4,y
            sta   BootStr+2,x
            inx
            iny
            bra   :c
:d          rep   #$20
            mx    %00
            lda   BootStr+1,x       ; (the last character: no ':' at the end)
            and   #$FF
            jsr   IsSep
            bne   :set
            dex
:set        stx   BootLen
            stx   BootStr
:x          rts

* IsBootRec: carry set if the record at X (GS/OS string) is BootStr
IsBootRec   stx   SP1
            lda   (SP1)
            cmp   BootStr
            bne   :no
            sta   T3
            ldy   #0
:c          cpy   T3
            bcs   :yes
            phy
            iny
            iny
            lda   (SP1),y
            ply
            and   #$FF
            jsr   Upper
            sta   T4
            lda   BootStr+2,y
            and   #$FF
            jsr   Upper
            cmp   T4
            bne   :no
            iny
            bra   :c
:yes        sec
            rts
:no         clc
            rts

*-------------------------------------------------------------
* The scan
*-------------------------------------------------------------
DoScan      PushLong OnbRect
            Tool  _EraseRect
            lda   #12
            sta   PX
            lda   #14
            sta   PY
            ldx   #TitleSTx
            jsr   DrawAt
            stz   NFound
            stz   StopFlag
            stz   Depth
            stz   VolI
:v          lda   VolI
            cmp   NVols
            bcs   :done
            lda   StopFlag
            bne   :done
            asl
            tax
            lda   VolSel,x
            beq   :nv
            lda   VolI
            jsr   VolAddr
            tax
            ldy   #ScanP
            jsr   CopyGS
            stz   IsBoot
            lda   VolI
            cmp   BootIdx
            bne   :go
            inc   IsBoot
:go         jsr   ScanFolder
:nv         inc   VolI
            bra   :v
:done       lda   #1
            sta   OState
            stz   OTop
            rts

* ScanFolder: the folder ScanP, and the ones in it
ScanFolder  lda   Depth
            cmp   #MaxDepth
            bcc   :go
            rts
:go         ldx   #ScanP
            lda   #1
            jsr   OpenFile
            bcc   :open
            rts
:open       lda   Depth
            asl
            tax
            lda   OpenParms+2
            sta   RefStack,x
            jsr   ScanStatus
:next       lda   StopFlag
            bne   :close
            lda   NFound
            cmp   #MaxFound
            bcs   :close
            lda   Depth
            asl
            tax
            lda   RefStack,x
            sta   DirParms+2
            lda   #1
            sta   DirParms+6
            sta   DirParms+8
            GSOS  _GetDirEntryGS;DirParms
            bcs   :close
            lda   DirParms+16
            cmp   #$0F
            beq   :folder
            cmp   #tS16
            beq   :app
            cmp   #tSYS
            bne   :next
:app        jsr   AddFound
            bra   :next
:folder     jsr   EnterFolder
            bra   :next
:close      lda   Depth
            asl
            tax
            lda   RefStack,x
            sta   CloseParms+2
            GSOS  _CloseGS;CloseParms
            rts

* EnterFolder: the entry just read (a folder) scanned too; the System
* folder at the top of a disk is not
EnterFolder lda   Depth
            bne   :ok
            ldx   #SystemTx
            jsr   NameIs
            bcs   :skip
:ok         lda   ScanP
            pha
            jsr   AppendName
            bcs   :r
            inc   Depth
            jsr   ScanFolder
            dec   Depth
:r          pla
            sta   ScanP
:skip       rts

* NameIs: carry set if the entry's name is the capitals at X (a C string)
NameIs      stx   SP1
            ldy   #0
:c          lda   (SP1),y
            and   #$FF
            beq   :end
            sta   T0
            cpy   NameRes+2
            bcs   :no
            lda   NameRes+4,y
            and   #$FF
            jsr   Upper
            cmp   T0
            bne   :no
            iny
            bra   :c
:end        cpy   NameRes+2
            bne   :no
            sec
            rts
:no         clc
            rts

* AppendName: ScanP gets ':' and the entry's name (carry set: too long)
AppendName  lda   ScanP
            clc
            adc   NameRes+2
            inc
            cmp   #PathMax
            bcs   :no
            ldx   ScanP
            sep   #$20
            mx    %10
            lda   #':'
            sta   ScanP+2,x
            inx
            ldy   #0
:c          cpy   NameRes+2
            bcs   :d
            lda   NameRes+4,y
            sta   ScanP+2,x
            inx
            iny
            bra   :c
:d          rep   #$20
            mx    %00
            stx   ScanP
            clc
            rts
:no         sec
            rts

* AddFound: the entry just read (an application) onto the list, but
* not ProDOS itself
AddFound    ldx   #ProDOSTx
            jsr   NameIs
            bcs   :x
            lda   ScanP
            pha
            jsr   AppendName
            bcs   :r
            ldx   #ScanP
            ldy   #FilePath
            jsr   CopyGS
            pla
            sta   ScanP
            jmp   StoreFound
:r          pla
            sta   ScanP
:x          rts

* StoreFound: FilePath onto the list ("*" for the boot disk's name)
StoreFound  lda   IsBoot
            beq   :copy
            lda   BootLen
            sta   T3
            ldx   T3
            ldy   #1
            sep   #$20
            mx    %10
            lda   #'*'
            sta   FilePath+2
:s          cpx   FilePath
            bcs   :sd
            lda   FilePath+2,x
            sta   FilePath+2,y
            inx
            iny
            bra   :s
:sd         rep   #$20
            mx    %00
            sty   FilePath
:copy       lda   NFound
            jsr   FoundPtr
            lda   FilePath
            inc
            inc
            sta   T3
            ldy   #0
            sep   #$20
            mx    %10
:c          cpy   T3
            bcs   :d
            lda   FilePath,y
            sta   [Ptr],y
            iny
            bra   :c
:d          rep   #$20
            mx    %00
            lda   NFound
            asl
            tax
            stz   FoundSel,x
            inc   NFound
            rts

* ScanStatus: what is being scanned, in the line under the list; Esc
* stops
ScanStatus  PushLong InfoRect
            Tool  _EraseRect
            ldx   #ScanTx
            jsr   MsgStart
            lda   ScanP
            sta   T3
            ldy   #0
            lda   T3
            cmp   #56
            bcc   :s
            sec
            sbc   #56
            tay
:s          ldx   #0                ; (the end of MsgBuf)
:e          lda   MsgBuf,x
            and   #$FF
            beq   :c
            inx
            bra   :e
:c          cpy   T3
            bcs   :d
            phy
            iny
            iny
            lda   ScanP,y
            ply
            sep   #$20
            mx    %10
            sta   MsgBuf,x
            rep   #$20
            mx    %00
            inx
            iny
            bra   :c
:d          lda   #0
            sta   MsgBuf,x
            lda   #12
            sta   PX
            lda   #OInfoY
            sta   PY
            ldx   #MsgBuf
            jsr   DrawAt
:k          pha
            pea   $0008             ; keys
            PushLong EvRec2
            Tool  _GetNextEvent
            pla
            beq   :x
            lda   EvRec2+2
            and   #$7F
            cmp   #K_ESC
            bne   :k
            inc   StopFlag
            bra   :k
:x          rts

*-------------------------------------------------------------
* The apps checked become slots
*-------------------------------------------------------------
AddSelected stz   AddI
            stz   AddN
:l          lda   AddI
            cmp   NFound
            bcs   :done
            asl
            tax
            lda   FoundSel,x
            beq   :next
            lda   NSlots
            cmp   #MaxSlots
            bcs   :full
            lda   AddI
            jsr   FoundPtr
            jsr   IsDup
            bcs   :next
            lda   NSlots
            sta   CurI
            jsr   ClearUse
            lda   CurI
            jsr   PathOf
            sta   SP2
            lda   [Ptr]
            inc
            inc
            sta   T3
            ldy   #0
            sep   #$20
            mx    %10
:c          cpy   T3
            bcs   :cd
            lda   [Ptr],y
            sta   (SP2),y
            iny
            bra   :c
:cd         rep   #$20
            mx    %00
            lda   CurI
            jsr   DefaultName
            inc   NSlots
            inc   AddN
:next       inc   AddI
            bra   :l
:full       ldx   #FullTx
            jsr   Alert
:done       lda   AddN
            beq   :x
            Tool  _WaitCursor
            jsr   ScanAll           ; (their icons and dates)
            Tool  _InitCursor
            jsr   SaveSlots
            jmp   Relayout
:x          rts

* IsDup: carry set if the app at Ptr is a slot already
IsDup       stz   DupI
:s          lda   DupI
            cmp   NSlots
            bcs   :no
            jsr   PathOf
            sta   SP1
            lda   (SP1)
            cmp   [Ptr]
            bne   :nx
            sta   T3
            ldy   #0
:c          cpy   T3
            bcs   :yes
            phy
            iny
            iny
            lda   (SP1),y
            and   #$FF
            jsr   Upper
            sta   T4
            lda   [Ptr],y
            and   #$FF
            jsr   Upper
            ply
            cmp   T4
            bne   :nx
            iny
            bra   :c
:nx         inc   DupI
            bra   :s
:yes        sec
            rts
:no         clc
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
FileLen     dw    0
ContRect    dw    0,0,0,0
FrRect      dw    0,0,0,0
InRect      dw    0,0,68,300
InTop       dw    0,0,40,300
InCanRect   dw    46,130,59,204
InOKRect    dw    46,218,59,282
NBtn        dw    0
HitCtl      adrl  0
BtnH        ds    8*4
BtnCode     ds    8*2
OKBt        str   'OK'
InField     dw    19,8,35,292

PfxParms    dw    2
            dw    0                 ; prefix 0
            adrl  FilePath
BootParms   dw    1
            adrl  VolBuf
VolBuf      dw    68                ; buffer size, then a GS/OS string
            ds    66
DInfoP      dw    3
DInfoNum    dw    1
            adrl  DevRB
DInfoChar   dw    0
DStP        dw    5
DStNum      dw    0
            dw    0                 ; status code 0: the device's status
            adrl  DStList
            adrl  6
            adrl  0
DStList
DStWord     dw    0
            adrl  0
DevRB       dw    36
DevLen      dw    0
            ds    34
VolP        dw    6
VolDev      adrl  0
            adrl  VolRB
VolTotal    adrl  0
VolFreeB    adrl  0
VolFSID     dw    0
VolBlkSz    dw    0
VolRB       dw    68
VolNmLen    dw    0
VolNmStr    ds    66
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
            dw    80,170,148,470
            adrl  $FFFFFFFF
            adrl  0

HelpParms     dw    78
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
            dw    30,40,200,600
            adrl  $FFFFFFFF
            adrl  0

OnbParms     dw    78
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
            dw    16,40,192,600
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
            asc   '--Find Apps...\N271*Ff',00
            asc   '--Edit Slots\N261*Ee',00
            asc   '--Change Slot...\N262',00
            asc   '--Rename Slot...\N263*Rr',00
            asc   '--Remove Slot\N264',00
            asc   '--Remove Missing Slots\N288',00
            asc   '--Move Left\N265',00
            asc   '--Move Right\N266V',00
            asc   '--Restart...\N289',00
            asc   '--Shut Down...\N290V',00
            asc   '--Quit to Finder\N256*Qq',00
            asc   '.',00
PageMenu    asc   '>>  Page  \N5',00
            asc   '--Next Page   (Tab)\N280*Tt',00
            asc   '--New Page...\N281',00
            asc   '--Rename Page...\N282',00
            asc   '--Remove Page\N283',00
            asc   '--Move Slot to Next Page\N284',00
            asc   '.',00
ViewMenu    asc   '>>  View  \N6',00
            asc   '--Show File Date\N285',00
            asc   '--Show Last Used\N286',00
            asc   '--Show Launch Count\N287',00
            asc   '.',00
HelpMenu    asc   '>>  Help  \N4',00
            asc   '--Starting Apps\N267',00
            asc   '--Editing the Slots\N268',00
            asc   '--The Menu Entries\N269',00
            asc   '--The Slots File\N270',00
            asc   '--Finding Apps\N272',00
            asc   '--Pages and Views\N273',00
            asc   '.',00
EditMenu    asc   '>>  Edit  \N3',00
            asc   '--Undo\N250*Zz',00
            asc   '--Cut\N251*Xx',00
            asc   '--Copy\N252*Cc',00
            asc   '--Paste\N253*Vv',00
            asc   '--Clear\N254',00
            asc   '.',00


Page1       da    P1a,P1b,P1c,P1d,P1e,P1f,0
P1a         asc   'Starting Apps',00
P1b         asc   'Click an icon and its app starts. When you quit that app, you are',00
P1c         asc   'back in GSLauncher.',00
P1d         asc   'The date under a name is when the file was last changed.',00
P1e         asc   'A dimmed icon with "not found" under it: the file is missing.',00
P1f         asc   'GSLauncher starts S16 and ProDOS 8 SYS files.   (Click or press a key.)',00
Page2       da    P2a,P2b,P2c,P2d,P2e,P2f,P2g,0
P2a         asc   'Editing the Slots',00
P2b         asc   'Add App (Apple-N): pick an app; it goes into the next free slot.',00
P2c         asc   'To change a slot: choose Edit Slots (Apple-E). A click then picks',00
P2d         asc   'a slot (a frame appears) instead of starting it. The arrow keys',00
P2e         asc   'pick the next one. Then use Change, Rename, Remove or Move.',00
P2f         asc   'Choose Edit Slots again, or press Esc, to start apps again.',00
P2g         asc   '(Click or press a key.)',00
Page3       da    P3a,P3b,P3k,P3c,P3d,P3e,P3f,P3m,P3g,P3n,P3h,P3i,P3j,0
P3a         asc   'The Menu Entries',00
P3b         asc   'Add App:  an app into a new slot.',00
P3k         asc   'Find Apps:  looks on your disks for apps and lists them to add.',00
P3c         asc   'Edit Slots:  a click picks a slot instead of starting it.',00
P3d         asc   'Change Slot:  another app for the picked slot.',00
P3e         asc   'Rename Slot:  the name under the icon (empty: the file name).',00
P3f         asc   'Remove Slot:  the picked slot goes.',00
P3m         asc   'Remove Missing Slots:  removes the slots on this page whose app is gone.',00
P3n         asc   'Restart, Shut Down:  restart or switch off the computer (it asks first).',00
P3g         asc   'Move Left, Move Right:  change the order of the slots.',00
P3h         asc   'Quit to Finder:  starts the Finder.',00
P3i         asc   'Change, Rename, Remove and Move need Edit Slots and a picked slot.',00
P3j         asc   '(Click or press a key.)',00
Page5       da    P5a,P5b,P5c,P5d,P5e,P5f,P5g,0
P5a         asc   'Finding Apps',00
P5b         asc   'Find Apps (Apple-F) looks on your disks for S16 and ProDOS 8 apps.',00
P5c         asc   'It opens by itself the first time GSLauncher starts (no slots file).',00
P5d         asc   'First check the disks to look at (the boot disk is checked), then Scan.',00
P5e         asc   'Then check the apps to add and click Add Selected. Esc stops a scan.',00
P5f         asc   'The System folder and ProDOS itself are left out. Apps already in',00
P5g         asc   'the launcher are not added twice.   (Click or press a key.)',00
Page6       da    P6a,P6b,P6c,P6d,P6e,P6f,P6g,P6h,P6i,0
P6a         asc   'Pages and Views',00
P6b         asc   'Pages are tabs across the top: up to 4, each with up to 18 slots.',00
P6c         asc   'The tabs show when there is more than one page. Click a tab, or press Tab.',00
P6d         asc   'Page menu: New, Rename and Remove Page (its slots go, not the apps), and',00
P6e         asc   'Move Slot to Next Page (Edit Slots first, then pick the slot).',00
P6f         asc   'View menu: the third line under a name shows the date of the file, when',00
P6g         asc   'the app was last started from GSLauncher, or how often it was started.',00
P6h         asc   'Keys 1 to 9 start the slot with that number (in Edit Slots: pick it).',00
P6i         asc   '(Click or press a key.)',00
Page4       da    P4a,P4b,P4c,P4d,P4e,P4f,0
P4a         asc   'The Slots File',00
P4b         asc   'The slots are kept in Launcher.Slots, a text file next to',00
P4c         asc   'GSLauncher: one line per slot, name=path. A star at the start',00
P4d         asc   'of a path stands for the disk you started from.',00
P4e         asc   'You can edit the file with any text editor.',00
P4f         asc   '(Click or press a key.)',00

AboutTx     asc   '63/GSLauncher 1.1'
            db    $0D
            put   builddate.s
            db    $0D
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
CaretTx     asc   '_',00

OState      dw    0                 ; 0 which disks, 1 which apps
OTop        dw    0
NFound      dw    0
NVols       dw    0
BootIdx     dw    $FFFF
BootLen     dw    0
IsBoot      dw    0
StopFlag    dw    0
Depth       dw    0
VolI        dw    0
RowI        dw    0
RowIdx      dw    0
RowY        dw    0
BtnX        dw    0
AddI        dw    0
AddN        dw    0
DupI        dw    0
FirstRun    dw    0
OnbRect     dw    0,0,176,560
InfoRect    dw    134,0,150,560
OnbR        dw    0,0,0,0
ListRect    dw    34,0,134,560
MousePt     dw    0,0
SbThumbTop  dw    0
SbThumbH    dw    0
SbTravel    dw    0
DragOff     dw    0
DragPos     dw    0
Btns0       da    12,70,ScanBt,1
            da    82,128,AllBt,2
            da    140,198,NoneBt,3
            da    480,548,CancelBt,4
            dw    $FFFF
Btns1       da    12,130,AddBt,5
            da    142,188,AllBt,2
            da    200,258,NoneBt,3
            da    480,548,CancelBt,4
            dw    $FFFF
ScanBt      str   'Scan'
AllBt       str   'All'
NoneBt      str   'None'
CancelBt    str   'Cancel'
AddBt       str   'Add Selected'
TitleVTx    asc   'Find Apps: which disks?',00
SubVTx      asc   'Check the disks to look at. GSLauncher finds S16 and ProDOS 8 applications.',00
TitleFTx    asc   'Find Apps: the applications found',00
SubFTx      asc   'Check the ones to add to the launcher.',00
TitleSTx    asc   'Find Apps: looking ...',00
InfoVTx     asc   'Click a disk to check or uncheck it. Scan can take a while.',00
NoneTx      asc   'No applications found.',00
FoundTx     asc   ' found. Check the ones to add.',00
FullListTx  asc   ' (the list is full)',00
BootTx      asc   '   (boot disk)',00
ScanTx      asc   'Looking in ',00
SystemTx    asc   'SYSTEM',00
ProDOSTx    asc   'PRODOS',00
ScanP       ds    PathSz
RefStack    ds    MaxDepth*2+2
VolRec      ds    MaxVols*36
VolSel      ds    MaxVols*2
FoundSel    ds    MaxFound*2
BootStr     ds    40
NGroups     dw    1
CurG        dw    0
MLen        dw    0
ViewMode    dw    0
TopOff      dw    0
FPos        dw    0
FEnd        dw    0
WPage       dw    0
HdrSeen     dw    0
PageLines   dw    0
SerI        dw    0
CIdx        dw    0
RPg         dw    0
RLen        dw    0
ROld        dw    0
ROff        dw    0
RTail       dw    0
RTailN      dw    0
RDelta      dw    0
MoveTo      dw    0
XLen        dw    0
DrawG       dw    0
InQP        dw    InQTx
DigTx       dw    0
DefPageTx   asc   'Apps',00
PageQTx     asc   'Name for this page:',00
NeverTx     asc   'never used',00
NotUsedTx   asc   'not used yet',00
LaunchTx    asc   ' launch',00
LaunchesTx  asc   ' launches',00
MaxPgTx     asc   '43/There can be 4 pages at most.'
            asc   '/^#0',00
OnePgTx     asc   '43/There is only one page.'
            asc   '/^#0',00
NoMissTx    asc   '33/No slot on this page has a missing app.'
            asc   '/^#0',00
DelPgTx     asc   '43/Remove this page and its slots? The apps themselves are not touched.'
            asc   '/^Remove/Cancel',00
RestartQTx  asc   '43/Restart the computer now?'
            asc   '/^Restart/Cancel',00
ShutQTx     asc   '43/Shut down the computer now?'
            asc   '/^Shut Down/Cancel',00
ShutErrTx   asc   '43/The computer could not be shut down.'
            asc   '/^#0',00
ShutParms   dw    1
            dw    0
PageName    ds    MaxGroups*32
PageOff     ds    MaxGroups*2
PageLen     ds    MaxGroups*2
SlotCount   ds    MaxSlots*2
SlotUsed    ds    MaxSlots*DateSz
Master      ds    MasterMax+4
LoadBuf     ds    MasterMax+400
XLine       ds    400
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
SlotIcon    ds    MaxSlots*IconMax
