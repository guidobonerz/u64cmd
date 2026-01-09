
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
    tya
    pha
    lda logging
    cmp #$01
    bne skip
    lda #<text
    ldy #>text
    jsr STROUT
skip:
    pla
    tay
    pla
}

.macro print(text){
    pha
    tya
    pha
    lda #<text
    ldy #>text
    jsr STROUT
    pla
    tay
    pla
}

.macro sendCommand(cmdStart,cmdEnd){
    pha
    tya
    pha
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
    pla
    tay    
    pla
}

status: .byte 00
logging: .byte 00

start:
    jsr checkU64
    sendCommand(DOS_CMD_ECHO,DOS_CMD_ECHO_END)
    jsr readData
    jsr logStatus
    jsr acceptData
    jsr logStatus
    //print(dataBuffer)
    sendCommand(DOS_CMD_IDENTIFY,DOS_CMD_IDENTIFY_END)
    jsr readData
    jsr logStatus
    jsr acceptData
    jsr logStatus
    print(dataBuffer)
    rts    

checkU64:{
    lda $df1d
    cmp #$00 //normalC64
    bne checkU64_ci_off
    print(txtNormalC64)
    jmp checked
checkU64_ci_off:
    cmp #$ff //u64 deactivated cmd interface
    bne checkU64_ci_on
    print(txtUltimate64InactiveCI)
    jmp checked
checkU64_ci_on:    
    cmp #$c9 //u64 activated cmd interface 
    bne unkown
    print(txtUltimate64ActiveCI)
    jmp checked
unkown:
    log(txtUnkownDevice)
checked:
    rts
}

commandLength: .word 0

_sendCommand:{
    log(txtPrepare)    
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
    jsr logStatus
    jsr waitForIdle
    ldy #$00
writeCommand:
    log(txtWrite)
    lda (CMD_POINTER),y
    sta DATA_REG
    cpy commandLength
    beq pushCommand
    iny 
    jmp writeCommand
pushCommand:
    log(txtPush)
    lda #$01 // PUSH_CMD
    sta CONTROL_REG
    jsr logStatus
checkForError:
    lda STATUS_REG
    and #$04
    cmp #$04
    bne waitBusyClear
    log(txtErrorAbort)
    lda STATUS_REG
    ora #$08
    sta STATUS_REG
    jmp _sendCommand
waitBusyClear:    
    lda STATUS_REG
    and #$10
    cmp #$10
    beq waitBusyClear
exit:
    print(txtCommandSent)
    jsr logStatus
    rts
}

waitForIdle:{
    jsr logStatus
    lda STATUS_REG
    and #%00110000
    cmp #$00
    beq isIdle
    log(txtBusy)
    jmp waitForIdle
isIdle:    
    jsr logStatus
    log(txtIdle)
    rts
}

dataBufferCount: .byte 00
readData:{
    log(txtRead)
    lda #$00
    sta dataBufferCount
    ldx #$00
readData:
    lda STATUS_REG
    and #%10000000 // DATA_AV
    cmp #%10000000
    bne noMoreData
    lda RESP_DATA_REG
    sta dataBuffer,x
    inx
    jmp readData
noMoreData:
    inx
    lda #$00
    sta dataBuffer,x // add termination
    txa
    jsr printValue
    rts
}

acceptData:{
    lda CONTROL_REG
    ora #$02 // DATA_ACC
    sta CONTROL_REG
waitForAcceptance:
    lda STATUS_REG
    and #$02 // DATA_ACC
    cmp #$00
    beq accepted
    jmp waitForAcceptance
accepted:
    rts
}

printValue:{
    sta status
    jsr setStatusNumber
    print(txtValue)
    jsr setBinaryNumber
    print(txtStatusValue)
    rts
}

logStatus:{
    lda STATUS_REG
    sta status
    jsr setStatusNumber
    log(txtStatusRegister)
    jsr setBinaryNumber
    log(txtStatusValue)
    rts
}


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

setStatusNumber: {
    lda status
    ldx #$2f
    sec
hundreds:
    inx
    sbc #100
    bcs hundreds
    adc #100
    stx txtStatusValue
    ldx #$2f
    sec
tens:
    inx
    sbc #10
    bcs tens
    adc #10
    stx txtStatusValue+1
    ora #$30
    sta txtStatusValue+2
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
txtPush:
.text "PUSH DATA"
.byte 13,0
txtCommandSent:
.text "COMMAND SENT"
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
txtStatusValue:
.text "000"
.text "/"
txtStatusBinaryValue:
.text "00000000"
.byte 13,0

DOS_CMD_ECHO:
.byte $01,$f0
DOS_CMD_ECHO_END:
DOS_CMD_IDENTIFY:
.byte $01,$01
DOS_CMD_IDENTIFY_END:

dataBuffer:
.fill DATA_BUFFER_SIZE, 0