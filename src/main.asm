
*=$0801

:BasicUpstart2(start)


//.encoding "screencode_upper"
.const STROUT                = $ab1e



.const CONTROL_REG	         = $df1c
.const STATUS_REG		     = $df1c
.const DATA_REG              = $df1d
.const ID_REG                = $df1d
.const RESP_DATA_REG         = $df1e
.const STATUS_DATA_REG       = $df1f
.const CONTROL_CLR_ERR       = %00001000
.const CONTROL_ABORT         = %00000100
.const CONTROL_DATA_AC       = %00000010
.const CONTROL_PUSH_CMD      = %00000001
.const STATUS_CMD_BUSY       = %00000001
.const STATUS_DATA_ACC       = %00000010
.const STATUS_ABORT_P        = %00000100
.const STATUS_ERROR          = %00001000
.const STATUS_STAT_IDLE      = %00000000
.const STATUS_STAT_CMD_BUSY  = %00010000
.const STATUS_STAT_DATA_LAST = %00100000
.const STATUS_STAT_DATA_MORE = %00110000
.const STATUS_STAT_AV        = %01000000
.const STATUS_DATA_AV        = %10000000

.const CMD_POINTER           =$9e
.const CMD_POINTER_END       =$a5
.const CMD_POINTER_END_COPY  =$a9

.const DATA_BUFFER_SIZE	     = 1792
.const STATUS_QUEUE_SIZE     = 512

.macro log(text){
    pha
    txa                     
    pha
    tya
    pha
    php
    lda logging
    cmp #$01
    bne skip
    lda #<text
    ldy #>text
    jsr STROUT
skip:
    plp
    pla
    tay
    pla
    tax
    pla
}

.macro print(text){
    pha
    txa                     
    pha
    tya
    pha
    php
    lda #<text
    ldy #>text
    jsr STROUT
    plp
    pla
    tay
    pla
    tax
    pla
}

.macro sendCommand(cmdStart,cmdEnd){
    pha
    txa                     
    pha
    tya
    pha
    php
    jsr clearBuffer
    lda #<cmdStart
    sta CMD_POINTER
    lda #>cmdStart
    sta CMD_POINTER+1
    lda #<cmdEnd
    sta CMD_POINTER_END
    sta CMD_POINTER_END_COPY
    lda #>cmdEnd
    sta CMD_POINTER_END+1
    sta CMD_POINTER_END_COPY+1
    jsr _sendCommand
    plp
    pla
    tay
    pla
    tax
    pla
}

.macro printIPAddress(buffer){
    lda buffer
    sta uint8
    jsr setUint8
    print(txtuint8)
    print(txtDot)
    lda buffer+1
    sta uint8
    jsr setUint8
    print(txtuint8)
    print(txtDot)
    lda buffer+2
    sta uint8
    jsr setUint8
    print(txtuint8)
    print(txtDot)
    lda buffer+3
    sta uint8
    jsr setUint8
    print(txtuint8)
    print(CRLF)
}

status: .byte 00
logging: .byte 00
uppercase: .byte 00
uint8: .byte 00
uint16: .byte 00

start:
    jsr checkU64
    lda type
    cmp #$ff
    beq isU64
    jmp exit
isU64:
    jsr identify
    //jsr changeDir
    //jsr getPath
    //jsr openDir
    //jsr getDir
    jsr getNetworkInterfaces
        
exit:
    rts    

type: .word 0

//.align $100
echo:{
    sendCommand(DOS_CMD_ECHO,DOS_CMD_ECHO_END)
    jsr readData
    jsr accept
    rts
}
//.align $100
identify:{
    print(txtIdentity)
    sendCommand(DOS_CMD_IDENTIFY,DOS_CMD_IDENTIFY_END)
    jsr readData
    jsr accept
    print(dataBuffer)
    print(CRLF)
    rts
}
//.align $100
changeDir:{
    print(txtChangeDir)
    sendCommand(DOS_CMD_CHANGE_DIR,DOS_CMD_CHANGE_DIR_END)
    jsr readStatusData
    jsr accept
    print(statusDataBuffer)
    print(CRLF)
    rts
}
//.align $100
getPath:{
    print(txtCurrentPath)
    sendCommand(DOS_CMD_GET_PATH,DOS_CMD_GET_PATH_END)
    lda #$01
    sta uppercase
    jsr readData
    jsr accept
    lda #$00
    sta uppercase
    print(dataBuffer)
    print(CRLF)
    rts
}
//.align $100
createDir:{
    sendCommand(DOS_CMD_CREATE_DIR,DOS_CMD_CREATE_DIR_END)
    jsr readData
    jsr accept
    //print(dataBuffer)
    //print(CRLF)
    rts
}
//.align $100
openDir:{
    print(txtOpenDir)
    sendCommand(DOS_CMD_OPEN_DIR,DOS_CMD_OPEN_DIR_END)
    jsr readStatusData
    jsr accept
    print(statusDataBuffer)
    print(CRLF)
    rts
}
//.align $100
getDir:{
    print(txtGetDir)
    sendCommand(DOS_CMD_READ_DIR,DOS_CMD_READ_DIR_END)
readList:    
    lda STATUS_REG
    and #%10000000 // DATA_AV
    cmp #%10000000
    bne exit
    lda #$01
    sta uppercase
    jsr readData
    jsr accept
    lda #$00
    sta uppercase
    print(dataBuffer+1)
    print(CRLF)
    jmp readList
exit:
    rts
}

networkInterfaceCount: .byte 0
getNetworkInterfaces:{
    print(txtNetworkInterfaces)
    sendCommand(NET_CMD_GET_INTERFACE_COUNT,NET_CMD_GET_INTERFACE_COUNT_END)
    jsr readData
    jsr readStatusData
    jsr accept
    lda dataBuffer
    sta networkInterfaceCount
    sta uint8
    jsr setUint8
    print(txtuint8)
    print(CRLF)
    print(statusDataBuffer)
    print(CRLF)
    ldx #$00
loop:
    cpx networkInterfaceCount
    bcs exit
    stx NET_CMD_GET_IP_ADDRESS+2
    txa
    pha
    jsr getIpAddress
    pla
    tax
    inx
    jmp loop
exit:    
    rts
}


getIpAddress:{
    print(txtIpAdresses)
    sendCommand(NET_CMD_GET_IP_ADDRESS,NET_CMD_GET_IP_ADDRESS_END)
    jsr readData
    jsr readStatusData
    jsr accept
    print(txtIpAddress)
    printIPAddress(dataBuffer)
    print(txtNetMask)
    printIPAddress(dataBuffer+4)
    print(txtGateway)
    printIPAddress(dataBuffer+8)
    print(statusDataBuffer)
    print(CRLF)
    rts
}
//.align $100
checkU64:{
    lda $df1d
    cmp #$00 //normalC64
    beq normal
    jmp checkU64_ci_off
normal:
    lda #$01
    sta type
    print(txtNormalC64)
    jmp checked
checkU64_ci_off:
    cmp #$ff //u64 deactivated cmd interface
    beq u64_ci_off
    jmp checkU64_ci_on
u64_ci_off:
    lda #$f0
    sta type
    print(txtUltimate64InactiveCI)
    jmp checked
checkU64_ci_on:    
    cmp #$c9 //u64 activated cmd interface 
    beq u64_ci_on
    jmp unkown
u64_ci_on:
    lda #$ff
    sta type
    print(txtUltimate64ActiveCI)
    jmp checked
unkown:
    lda #$00
    sta type
    log(txtUnkownDevice)
checked:
    rts
}

//.align 100
clearBuffer:{
    ldx #$ff
loop:
    lda #$00
    sta dataBuffer,x
    sta statusDataBuffer,x
    dex
    bne loop
    rts
}



//.align $100
commandLength: .word 0

_sendCommand:{
    //log(txtPrepare)    
    lda #$00
    sta commandLength
    sta commandLength+1
calcLength:
    lda CMD_POINTER_END
    cmp CMD_POINTER
    bne doDecrementEndPointer
    lda CMD_POINTER_END+1
    cmp CMD_POINTER+1
    beq resetEndPointer
doDecrementEndPointer:
    sec
    lda CMD_POINTER_END
    sbc #$01
    sta CMD_POINTER_END
    lda CMD_POINTER_END+1
    sbc #$00
    sta CMD_POINTER_END+1
    inc commandLength
    bne calcLength
    inc commandLength+1
    jmp calcLength
resetEndPointer:
    lda CMD_POINTER_END_COPY
    sta CMD_POINTER_END
    lda CMD_POINTER_END_COPY+1
    sta CMD_POINTER_END+1  
    dec commandLength
    ///--------------------
    //log(txtBusy)
    //jsr logStatus
waitForIdle:
    lda STATUS_REG
    and #%00110000
    cmp #$00
    beq isIdle
    //log(txtBusy)
    jmp waitForIdle
    //--------------------
isIdle:
    //log(txtIdle)
    ldy #$00
    //log(txtWrite)
writeCommand:
    lda (CMD_POINTER),y
    sta DATA_REG
    cpy commandLength
    beq pushCommand
    iny 
    jmp writeCommand
pushCommand:
    //log(txtPush)
    lda CONTROL_REG
    ora #$01 // PUSH_CMD
    sta CONTROL_REG
checkForError:
    lda STATUS_REG
    and #$04
    cmp #$04
    bne waitBusyClear
    //log(txtErrorAbort)
    lda CONTROL_REG
    ora #$08
    sta CONTROL_REG
    jmp _sendCommand
waitBusyClear: 
    lda STATUS_REG
    and #$30
    cmp #$10
    bne exit
    jmp waitBusyClear
exit:
    //print(txtCommandSent)
    //jsr logStatus
    rts
}

//.align $100
readData:{
    //log(txtRead)
    ldx #$00
read:
    lda STATUS_REG
    and #%10000000 // DATA_AV
    cmp #%10000000
    beq hasData
    jmp noMoreData
hasData:
    lda RESP_DATA_REG
    ldy uppercase
    cpy #$01
    bne storeNormal
    cmp #97 
    bcs greaterThan
    jmp storeNormal
greaterThan:
    cmp #123
    bcc lessThan
    jmp storeNormal
lessThan:
    sec
    sbc #$20
storeNormal:
    sta dataBuffer,x
    inx
    jmp read
noMoreData:
    lda #$00
    sta dataBuffer,x // add termination
    rts
}

//.align $100
readStatusData:{
    ldx #$00
read:
    lda STATUS_REG
    and #%01000000 // DATA_AV
    cmp #%01000000
    beq store
    jmp noMoreData
store:    
    //log(txtRead)
    lda STATUS_DATA_REG
    sta statusDataBuffer,x
    inx
    //log(txt)
    jmp read
noMoreData:
    lda #$00
    sta statusDataBuffer,x // add termination
    rts
}

//.align $100
accept:{
    pha
    lda CONTROL_REG
    ora #$02 // DATA_ACC
    sta CONTROL_REG
waitForAcceptance:
    //log(txtWaitACK)
    lda STATUS_REG
    and #$02 // DATA_ACC
    cmp #$00
    bne waitForAcceptance
accepted:
    //log(txtAccepted)
    pla
    rts
}

printValue:{
    sta status
    //jsr setStatusNumber
    print(txtValue)
    jsr setBinaryNumber
    print(txtStatusValue)
    rts
}


logStatus:{
    pha
    lda STATUS_REG
    sta status
    //jsr setStatusNumber
    log(txtStatusRegister)
    jsr setBinaryNumber
    log(txtStatusValue)
    pla
    rts
}

//.align $100
setBinaryNumber: {
    lda status
loop:
    asl status
    lda #$30
    bcc zero
    lda #$31
    
zero:
    sta txtStatusBinaryValue,x
    inx
    cpx #$08
    bne loop
    rts
}
//.align $100
setUint8: {
    pha
    txa
    pha
    lda uint8
    ldx #$2f
    sec
hundreds:
    inx
    sbc #100
    bcs hundreds
    adc #100
    stx txtuint8
    ldx #$2f
    sec
tens:
    inx
    sbc #10
    bcs tens
    adc #10
    stx txtuint8+1
    ora #$30
    sta txtuint8+2
    pla
    tax
    pla
    rts
}


txtNormalC64:
.text "NORMAL C64"
.byte 13,0
txtUltimate64InactiveCI:
.text "ULTIMATE64 WITH INACTIVE CI"
.byte 13,0
txtUltimate64ActiveCI:
.text "ULTIMATE WITH ACTIVE CI"
.byte 13,0
txtUnkownDevice:
.text "UNKNOWN DEVICE"
.byte 13,0
txtIdle:
.text "IDLE"
.byte 13,0
txtNotIdle:
.text "NOT IDLE"
.byte 13,0
txtBusy:
.text "BUSY"
.byte 13,0
txtWaitACK:
.text "WAIT ACK"
.byte 13,0
txtPush:
.text "PUSH DATA"
.byte 13,0
txtCommandSent:
.text "COMMAND SENT"
.byte 13,0
txtIdentity:
.text "> IDENTITY"
.byte 13,0
txtLastData:
.text "LAST DATA"
.byte 13,0
txtMoreData:
.text "MORE DATA AVAILABLE"
.byte 13,0
txtSuccess:
.text "SUCCESS"
.byte 13,0
txtDataAvailable:
.text "DATA AVAILABLE"
.byte 13,0
txtAccepted:
.text "ACCEPTED"
.byte 13,0
txtErrorAbort:
.text "ERROR > ABORT"
.byte 13,0
txtPrepare:
.text "PREPARE"
.byte 13,0
txtGetDir:
.text "> GET DIR"
.byte 13,0
txtChangeDir:
.text "> CHANGE DIR"
.byte 13,0
txtCurrentPath:
.text "> CURRENT PATH"
.byte 13,0
txtOpenDir:
.text "> OPEN DIR"
.byte 13,0
txtNetworkInterfaces:
.text "> NETWORK INTERFACES"
.byte 13,0
txtIpAdresses:
.text "> IP ADRESSES"
.byte 13,0
txtWrite:
.text "WRITE DATA"
.byte 13,0
txtRead:
.text "READ DATA"
.byte 13,0
txtStatusRegister:
.text "STATUS REG: "
.byte 0
txtValue:
.text "VALUE: "
.byte 0
txtuint8:
.text "   "
.byte 0
txtStatusValue:
.text "000"
.text "/"
txtStatusBinaryValue:
.text "00000000"
CRLF:
.byte 13,0
txtDot:
.text "."
.byte 0
txtIpAddress:
.text "IP ADDRESS: "
.byte 0
txtNetMask:
.text "NET MASK  : "
.byte 0
txtGateway:
.text "GATEWAY   : "
.byte 0
DOS_CMD_IDENTIFY:
.byte $01,$01
DOS_CMD_IDENTIFY_END:

DOS_CMD_CHANGE_DIR:
.byte $01,$11
.text "/FLASH/ROMS"
.byte 0
DOS_CMD_CHANGE_DIR_END:

DOS_CMD_GET_PATH:
.byte $01,$12
DOS_CMD_GET_PATH_END:

DOS_CMD_OPEN_DIR:
.byte $01,$13
DOS_CMD_OPEN_DIR_END:

DOS_CMD_READ_DIR:
.byte $01,$14
DOS_CMD_READ_DIR_END:

DOS_CMD_CREATE_DIR:
.byte $01,$16
.text"TEST"
DOS_CMD_CREATE_DIR_END:

DOS_CMD_ECHO:
.byte $01,$f0
DOS_CMD_ECHO_END:

NET_CMD_GET_INTERFACE_COUNT:
.byte $03,$02
NET_CMD_GET_INTERFACE_COUNT_END:

NET_CMD_GET_IP_ADDRESS:
.byte $03,$05,0
NET_CMD_GET_IP_ADDRESS_END:



//.align $100
dataBuffer:
//.fill DATA_BUFFER_SIZE, 0
.fill 80,0
statusDataBuffer:
.fill 40,0
//.fill DATA_BUFFER_SIZE, 0