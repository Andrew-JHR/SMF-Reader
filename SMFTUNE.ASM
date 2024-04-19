//ANDREWJA JOB  SP,CLASS=A,MSGCLASS=X,NOTIFY=&SYSUID                
//STEP1    EXEC ASMACL  G,PARM.G='0D,0E,0F,01,05,06,07,09'
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
SMFTUNE  CSECT
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
        BAL    R6,GET_PARMS         get parms
        B      GO_PROCESS           do the job
FINISH  EQU    *
        BAL    R6,CLOSE_FILES       close files
        B      RETURN               return to system
*
*-------------------------------------------------------*
*
GET_PARMS  EQU  *
         L     R2,0(,R2)            get parm addr.
         LH    R3,0(,R2)            length
         LTR   R3,R3                chk length
         BNZ   GET_PARM_01          having parms

         MVC   WK,BLANKS            clear
         MVC   WK(18),=C'No Parm Specified!'
         PUT   PRINT,WK             print the message
         B     FINISH               go back

GET_PARM_01 EQU  *
         SR    R9,R9                parm length correct?
         LA    R2,2(,R2)            skip the length
         LA    R4,LOOKUP            skip the length

GET_PARM_02 EQU  *
         LTR   R3,R3                all bytes processed ?
         BNH   GET_PARM_03          yes, branch

         MVC   0(2,R4),0(R2)        skip the length
         LA    R9,1(,R9)            add 1
         LA    R4,2(,R4)            next slot
         LA    R2,3(,R2)            next parm
         SH    R3,=H'3'             deduct the total count
         B     GET_PARM_02          loop thru all bytes
GET_PARM_03 EQU  *
         STH   R9,LOOKUP#           save the item number
         BR    R6
*
*-------------------------------------------------------*
*
OPEN_FILES EQU  *
         LR    R2,R1                save parm address
         OPEN  (SEQIN,UPDAT,PRINT,OUTPUT)
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
         BNE   GO_LOOP            no, don't collect
         CLC   SMF70STY,=X'0001'  subtype 1?
         BNE   GO_LOOP            no, don't collect

*--Loop Thru All Items Of Partition Data Section--------------------*
         L     R5,SMF70BCS        start of PR/SM section
         AR    R5,R4              start of PR/SM partition section
         LH    R9,SMF70BCL        each item's length
         LH    R3,SMF70BCN        how many items

         USING SMF70BCT,R5        addressibility

         MVC   BLACKLST,BLANKS    clear

LP_PART  EQU   *

         LA    R8,LOOKUP          table of the lpars to update
         LH    R7,LOOKUP#         how many items to check?

BLKLST00 EQU   *
         CLC   SMF70LPM+2(2),0(R8)  found ?
         BNE   BLKLST01
         OI    F_UPDT,L'F_UPDT    ind. an update is needed
         B     BLKLST02           found & jump out of the loop
BLKLST01 EQU   *
         LA    R8,2(,R8)          next
         BCT   R7,BLKLST00        loop thru all items
BLKLST02 EQU   *

         TM    F_UPDT,L'F_UPDT    need an update?
         BNO   BLKLST04           no, go check next record

         ICM   R12,B'0001',=X'FF'
         L     R10,SMF70BDS       starting slot
         LH    R11,SMF70BDN       how many of cpus used?

BLKLST03 EQU   *
         STC   R12,BLACKLST(R10)  put the mark
         LA    R10,1(,R10)        increase
         BCT   R11,BLKLST03

         NI    F_UPDT,X'FF'-L'F_UPDT  reset the ind.

BLKLST04 EQU   *

         AR    R5,R9              next item
         BCT   R3,LP_PART         loop thru all items

*--Loop Thru All Items Of Logical Processor Data Section------------*
         L     R5,SMF70BVS        start of logic processor sec.
         AR    R5,R4              addr of logic processor section
         LH    R9,SMF70BVL        each item's length
         LH    R3,SMF70BVN        how many items

         USING SMF70BPD,R5        addressibility

         LA    R7,BLACKLST        start of the item to do updates

LP_LOGP  EQU   *

         CLI   0(R7),X'FF'        need an update ?
         BNE   LP_LOGP_1          no, bypass

         MVC   SMF70PDT,LOWVALUE  clear dispatch time
         MVC   SMF70EDT,LOWVALUE  clear effective dispatch time
         MVC   SMF70WST,LOWVALUE  clear wait state time
         MVC   SMF70POW,LOWVALUE  clear polarization weight
         MVI   SMF70POF,X'00'     clear polarization flag

LP_LOGP_1 EQU  *
         AR    R5,R9              next item
         LA    R7,1(,R7)          increase 1
         BCT   R3,LP_LOGP         loop thru all items

LP_LOGP_2 EQU  *
         PUTX  SEQIN              write back

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
PRINT  DCB DSORG=PS,DDNAME=PRINT,MACRF=PM,LRECL=80
*
LOOKUP    DS  CL30
LOOKUP#   DS  H                  number of items
*
BLACKLST  DS  CL80
*
ENDADDR   DS    F                save the end addr of a rec
WK8       DS    D
*
FLAG      DS    X
          ORG   FLAG
F_UPDT    DS    0XL(B'10000000')  IND. ANY UNPRINTABLE CHAR FOUND.
          ORG
*
BLANKS    DC    120C' '
WK        DS    CL80
LOWVALUE  DC    8X'00'
*
*--------------------------------------------------------*
*
        ERBSMF70 1
*--------------------------------------------------------*
        END
/*
//*.SYSLMOD DD  DISP=SHR,DSN=SYS1.TEMPLINK(SMFTUNE)
//*.SEQIN   DD  DISP=SHR,DSN=SYS1.SMFSCRT.LP08
//*.PRINT   DD  SYSOUT=*
