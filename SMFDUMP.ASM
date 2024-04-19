//ANDREWJA JOB  CLASS=A,MSGCLASS=X,NOTIFY=&SYSUID                       
//STEP1    EXEC ASMACLG
//SYSIN    DD   *
         PRINT NOGEN
*
*------------------------------------------------*
*
         PRINT OFF
&REG     SETA  0
.LOOP    ANOP                              GENERATE REGS.
R&REG    EQU   &REG
&REG     SETA  &REG+1
         AIF   (&REG LE 15).LOOP
         PRINT ON
*
*------------------------------------------------*
*
*
*------------------------------------------------*
*
SMFDUMP  CSECT
         USING *,R15              setup addressibility                  00727800
         STM   R14,R12,12(R13)    save parent's register                00727900
         LR    R2,R13             parent's save area pointer
         B     CMNTTAIL           skip over the remarks                 00728000
*                                                                       00728100
CMNTHEAD EQU   *                                                        00728200
         PRINT GEN                print out remarks                     00728300
         DC    CL8'&SYSDATE'      compiling date                        00728400
         DC    C' '                                                     00728500
         DC    CL5'&SYSTIME'      compiling time                        00728600
         DC    C'ANDREW JAN'      author                                00728700
         CNOP  2,4                ensure half word boundary             00728800
         PRINT NOGEN              disable macro expansion               00728900
CMNTTAIL EQU   *                                                        00729000
                                                                        00730000
         BALR  R12,0
         BAL   R13,76(R12)
                                                                        00730000
         DROP  R15                avoid compiling warning               00791000
                                                                        00730000
SAVREG   DS    18F
         USING SAVREG,R13
         ST    R2,4(,R13)
         ST    R13,8(,R2)
*
*
*---MAINSTREAM------------------------------------*
*
*
        BAL    R6,OPEN_FILES        open files
        B      GO_PROCESS           do the job
FINISH  EQU    *
        BAL    R6,CLOSE_FILES       close files
        B      RETURN               return to system
*
*-------------------------------------------------------*
*
OPEN_FILES EQU  *
         OPEN  (SEQIN,INPUT,PRINT,OUTPUT)
         BR    R6
*
*-------------------------------------------------------*
*
GO_PROCESS  EQU   *

         USING SMF70HDR,R4        addressibility
GO_LOOP  EQU   *
         GET   SEQIN              read a record
         LR    R4,R1              base reg
         CLI   SMF70RTY,X'46'     type 70 ?
*        CLI   SMF70RTY,X'59'     type 89 ?
         BNE   GO_LOOP            no, don't collect
         CLC   SMF70STY,=X'0001'  subtype 1?
*        CLC   SMF70STY,=X'0002'  subtype 2?
         BNE   GO_LOOP            no, don't collect
         LH    R3,SMF70LEN        collect source length
         LR    R2,R4              copy source address
         LA    R8,WORK            target address
         LH    R9,=Y(L'WORK)      target length
         ICM   R3,B'1000',=C' '   clear the target's remaining bytes
         MVCL  R8,R2              do the move

         MVC   W_CENTURY(4),SMF70DTE make date visible
         CONVTOD CONVVAL=WK16,TODVAL=WK8,DATETYPE=YYDDD
         STCKCONV STCKVAL=WK8,CONVVAL=WK16,DATETYPE=YYYYMMDD

         UNPK  WK9,WK5            unpack to be in char

         MVC   WK(6),C_Y4MMDD+2   output yymmdd

         L     R10,SMF70TME       hundredths of seconds
         SRDA  R10,32(0)          R10 & R11
         D     R10,=F'360000'     cal. hours
         CVD   R11,WK8            bin to packed
         MVI   WK+6,C','          comma
         UNPK  WK+7(2),WK8+6(2)   dec
         OI    WK+8,X'F0'         readable
         SRDA  R10,32(0)          R10 & R11
         D     R10,=F'6000'       cal. mins
         CVD   R11,WK8            bin to packed
         MVI   WK+9,C'.'          period
         UNPK  WK+10(2),WK8+6(2)  dec
         OI    WK+11,X'F0'        readable
         MVI   WK+12,C','         comma

         PUT   PRINT,WK          print this item
         B     GO_LOOP            loop it
*
*--------------------------------------------------------*
*
CLOSE_FILES EQU  *
         CLOSE (SEQIN,,PRINT)       CLOSE OUTPUT
         BR    R6
*
*--------------------------------------------------------*
*
RETURN   EQU   *
         L     R13,4(R13)
         RETURN (14,12),RC=0        BACK TO CALLER
*
*--------------------------------------------------------*
*
         LTORG
*
*--------------------------------------------------------*
*
*
SEQIN  DCB DSORG=PS,DDNAME=SEQIN,MACRF=GL,EODAD=FINISH,BFTEK=A
PRINT  DCB DSORG=PS,DDNAME=PRINT,MACRF=PM
*
WK8       DS    D
WK16      DS   0F                work to convert time format
          DS    XL8              HHMMSSTHMIJU0000
WK5       DS   0CL5              5-byte field for unpk source
W_Y4MMDD  DS   0CL4              4-byte yyyymmdd after stckconv
W_CENTURY DS    CL1              x'01' means 20xx
W_JULIAN  DS    CL3              packed yyddd
          DS    F                reserved
*
WK9       DS    0CL9             9-byte field for unpk outcome
C_Y4MMDD  DS    CL8              8-byte yyyymmdd in character
          DS    CL1              working byte
WK        DS    CL13
WORK     DS    CL8192
*
*--------------------------------------------------------*
*
        ERBSMF70 1
        IFASMFRA 89
*--------------------------------------------------------*
        END
/*
//*.SYSMOD DD  DISP=SHR,DSN=SYS1.TEMPLINK(SMFDUMP)
//G.SEQIN  DD  DISP=SHR,DSN=SYS1.SMFSCRT.TEMP
//G.PRINT  DD  SYSOUT=*,LRECL=8192
