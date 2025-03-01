!c  acspec -- spectrum across an image, input complex

      complex a(65536),b(1024)
      dimension acc(1024)
      character*60 file

      if(iargc().lt.5)then
         print *,'usage: acspec file length firstline nlines firstpix '
         stop
      end if

      call getarg(2,file)
      read(file,*)len
      call getarg(3,file)
      read(file,*)line0
      call getarg(4,file)
      read(file,*)nlines
      call getarg(5,file)
      read(file,*)ip0
      call getarg(1,file)

      open(21,file=file,access='direct',recl=len*8)
!c  zero accumulator
      do k=1,1024
         acc(k)=0.
      end do
      do i=line0,line0+nlines-1
         read(21,rec=i,err=90)(a(k),k=1,len)
         do j=1,1024
            b(j)=a(ip0-1+j)
         end do
         call fft(b,1024,-1)
!c  accumulate powers
         do k=1,1024
            acc(k)=acc(k)+cabs(b(k))**2
         end do
      end do

 90   open(22,file='acspec.out')
      do i=1,1024
         write(22,*)i,sqrt(acc(i))
      end do
      close(22)

      end

!c  fft -- this is the four1 routine from numerical recipes
      SUBROUTINE FFT(DATA,NN,ISIGN)
      REAL*8 WR,WI,WPR,WPI,WTEMP,THETA
      DIMENSION DATA(*)
      N=2*NN
      J=1
      DO 11 I=1,N,2
        IF(J.GT.I)THEN
          TEMPR=DATA(J)
          TEMPI=DATA(J+1)
          DATA(J)=DATA(I)
          DATA(J+1)=DATA(I+1)
          DATA(I)=TEMPR
          DATA(I+1)=TEMPI
        ENDIF
        M=N/2
1       IF ((M.GE.2).AND.(J.GT.M)) THEN
          J=J-M
          M=M/2
        GO TO 1
        ENDIF
        J=J+M
11    CONTINUE
      MMAX=2
2     IF (N.GT.MMAX) THEN
        ISTEP=2*MMAX
        THETA=6.28318530717959D0/(ISIGN*MMAX)
        WPR=-2.D0*DSIN(0.5D0*THETA)**2
        WPI=DSIN(THETA)
        WR=1.D0
        WI=0.D0
        DO 13 M=1,MMAX,2
          DO 12 I=M,N,ISTEP
            J=I+MMAX
            TEMPR=SNGL(WR)*DATA(J)-SNGL(WI)*DATA(J+1)
            TEMPI=SNGL(WR)*DATA(J+1)+SNGL(WI)*DATA(J)
            DATA(J)=DATA(I)-TEMPR
            DATA(J+1)=DATA(I+1)-TEMPI
            DATA(I)=DATA(I)+TEMPR
            DATA(I+1)=DATA(I+1)+TEMPI
12        CONTINUE
          WTEMP=WR
          WR=WR*WPR-WI*WPI+WR
          WI=WI*WPR+WTEMP*WPI+WI
13      CONTINUE
        MMAX=ISTEP
      GO TO 2
      ENDIF
      RETURN
      END
