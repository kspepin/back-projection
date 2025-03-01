!  cctimeimage - image of correlation and time offset for a pixel

  real*4, allocatable:: array(:,:,:),data(:,:)
  character*300 str,cclist,infile,outfile,rscfile,filelist(100000)
  character*8 date1, date2
  character*14 rscstr

  if(iargc().lt.1)then
     print *,'Usage: ccvtimeimage cclist rsc-file'
     call exit
  end if

  call getarg(1,cclist)
  call getarg(2,rscfile)
  print *,trim(cclist),trim(rscfile)

! parameters of rsc file
  open(20,file=rscfile)
  read(20,'(a,i14)')rscstr,iwidth
  print *,rscstr,iwidth
  read(20,'(a,i14)')rscstr,ilength
  read(20,'(a,f14.8)')rscstr,xfirst
  read(20,'(a,f14.8)')rscstr,yfirst
  read(20,'(a,e20.8)')rscstr,xstep
  read(20,'(a,e20.8)')rscstr,ystep
  close(20)

  nac=iwidth/10-1
  ndn=ilength/10-1
  print *,'output file sizes ',nac,ndn

! create ccimage parameters file
  open(21,file='ccparameters')
  write(21,*)xfirst+(10-1)*xstep,'  long start'
  write(21,*)yfirst+(10-1)*ystep,'  lat start'
  write(21,*)10*xstep,'  long delta'
  write(21,*)10*ystep,'  lat delta'
  write(21,*)nac,ndn,'  point across, down'

  open(1,file=cclist)
  do i=1,1000000
     read(1,'(a)',end=99)infile
     filelist(i)=trim(infile)
     !  extract start, stop dates
     date1=infile(1:8)
     date2=infile(10:17)
     read(date1(1:4),'(i4)')iyear
     read(date1(5:6),'(i2)')imonth
     read(date1(7:8),'(i2)')iday
     jd1=jd(iyear,imonth,iday)
     read(date2(1:4),'(i4)')iyear
     read(date2(5:6),'(i2)')imonth
     read(date2(7:8),'(i2)')iday
     jd2=jd(iyear,imonth,iday)
     write(21,*)jd2-jd1,' ',trim(infile)
  end do
99 print *,'Done ',i
  nfiles=i-1
  close(1)
  close(21)

  allocate (array(nfiles,nac,ndn),data(iwidth*2,ilength))

  do i=1,nfiles
     open(21,file=filelist(i),access='stream')
     read(21)data
     close(21)
     do iac=1,nac
        do idn=1,ndn
           array(i,iac,idn)=data(iwidth+iac*10,idn*10)
        end do
     end do
  end do

!write image
  open(22,file='cctimeimage.dat',access='stream')
  write(22)array
  close(22)

  end


      INTEGER FUNCTION JD (YEAR,MONTH,DAY)
!
!---COMPUTES THE JULIAN DATE (JD) GIVEN A GREGORIAN CALENDAR
!   DATE (YEAR,MONTH,DAY).
!
      INTEGER YEAR,MONTH,DAY,I,J,K
!
      I= YEAR
      J= MONTH
      K= DAY
!     
      JD= K-32075+1461*(I+4800+(J-14)/12)/4+367*(J-2-(J-14)/12*12)/12-3*((I+4900+(J-14)/12)/100)/4
!
      RETURN
      END

!Conversion from a Julian date to a Gregorian calendar date.
      SUBROUTINE GDATE (JD, YEAR,MONTH,DAY)
!
!---COMPUTES THE GREGORIAN CALENDAR DATE (YEAR,MONTH,DAY)
!   GIVEN THE JULIAN DATE (JD).
!
      INTEGER JD,YEAR,MONTH,DAY,I,J,K
!
      L= JD+68569
      N= 4*L/146097
      L= L-(146097*N+3)/4
      I= 4000*(L+1)/1461001
      L= L-1461*I/4+31
      J= 80*L/2447
      K= L-2447*J/80
      L= J/11
      J= J+2-12*L
      I= 100*(N-49)+I+L
!
      YEAR= I
      MONTH= J
      DAY= K
!
      RETURN
      END
