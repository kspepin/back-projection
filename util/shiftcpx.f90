!c    shiftcpx - shift an image across and down (positive sense of args)
!c    

program shiftcpx

      implicit none
      integer*4    width,length,ranfftx, ranffty
      complex*8, allocatable :: array(:,:)
      complex*8, allocatable :: tempx(:),tempy(:),cpxphasex(:),cpxphasey(:)
      character*300 name
      character*100 str
      integer*8    iplanwidth,iplanlength,iplanwidthinv,iplanlengthinv
      integer*4 i
      real*8 phase, pi2, pi, xpix, ypix
      print *

!c    **********  input parameters  **********
!c    
!c    enter input parameters
!c    
      if(iargc().lt.5)then
         print *,'Usage: cpxfile width length xpix ypix'
         call exit
      end if

      call getarg(1,name)
      call getarg(2,str)
      read(str,*)width
      call getarg(3,str)
      read(str,*)length
      call getarg(4,str)
      read(str,*)xpix
      call getarg(5,str)
      read(str,*)ypix

!c    allocate array for full file
      allocate(array(width,length))

      pi = 4.d0*datan(1.d0)

!c    init transform lengths
      do i=1,20
         if(2**i.ge.width)go to 10
      end do
10      ranfftx=2**i
      allocate (tempx(ranfftx),cpxphasex(ranfftx))
      call sfftw_plan_dft_1d(iplanwidth, ranfftx, tempx, tempx, -1, 64)
      call sfftw_plan_dft_1d(iplanwidthinv, ranfftx, tempx, tempx, 1, 64)

      do i=1,20
         if(2**i.ge.length)go to 20
      end do
20      ranffty=2**i
      allocate (tempy(ranffty),cpxphasey(ranffty))
      call sfftw_plan_dft_1d(iplanlength, ranffty, tempy, tempy, -1, 64)
      call sfftw_plan_dft_1d(iplanlengthinv, ranffty, tempy, tempy, 1, 64)

!      print *,'ranfftx ranffty ',ranfftx, ranffty
!c    
!c    open input file
!c    
      open(21,file=name,access='direct',recl=width*length*8)
      read(21,rec=1)array

!c  first shift across
      cpxphasex=cmplx(0.,0.)
      do i=1,ranfftx/2
         phase=-float(i-1)/float(ranfftx)*2.*pi*xpix
         cpxphasex(i)=cmplx(cos(phase),sin(phase))
      end do
      do i=-1,-ranfftx/2,-1
         phase=-float(i)/float(ranfftx)*2.*pi*xpix
         cpxphasex(i+ranfftx+1)=cmplx(cos(phase),sin(phase))
      end do
!      print *,cpxphasex
      do i=1,length
         tempx=cmplx(0.,0.)
         tempx(1:width)=array(1:width,i)
         call sfftw_execute_dft(iplanwidth,tempx,tempx)
         tempx=tempx*cpxphasex
         call sfftw_execute_dft(iplanwidthinv,tempx,tempx)
         array(1:width,i)=tempx(1:width)/ranfftx
      end do

!c  now down
      cpxphasey=cmplx(0.,0.)
      do i=1,ranffty/2
         phase=-float(i-1)/float(ranffty)*2.*pi*ypix
         cpxphasey(i)=cmplx(cos(phase),sin(phase))
      end do
      do i=-1,-ranffty/2,-1
         phase=-float(i)/float(ranffty)*2.*pi*ypix
         cpxphasey(i+ranffty+1)=cmplx(cos(phase),sin(phase))
      end do
!      print *,cpxphasey
      do i=1,width
         tempy=cmplx(0.,0.)
         tempy(1:length)=array(i,1:length)
         call sfftw_execute_dft(iplanlength,tempy,tempy)
         tempy=tempy*cpxphasey
         call sfftw_execute_dft(iplanlengthinv,tempy,tempy)
         array(i,1:length)=tempy(1:length)/ranffty
      end do

      write(21,rec=1)array

    end program shiftcpx
