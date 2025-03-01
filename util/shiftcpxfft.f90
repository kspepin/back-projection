!c    shiftcpxfft - shift an image across and down (positive sense of args)
!c       shift by binary fraction of pixel

program shiftcpxfft

      use omp_lib
      implicit none
      integer*4    width,length,ranfftx, ranffty, novr
      complex*8, allocatable :: array(:,:)
      complex*8, allocatable :: tempx(:),tempy(:),tempxover(:),tempyover(:)
      character*300 name
      character*100 str
      integer*8    iplanwidth,iplanlength,iplanwidthinv,iplanlengthinv
      integer*4 i, j, ishift,ifrac
      real*8 phase, pi2, pi, xpix, ypix, frac

      novr = 16 ! amount for oversampling = inverse of output spacing


!c    **********  input parameters  **********
!c    
!c    enter input parameters
!c    
      if(iargc().lt.5)then
         print *,'Usage: shiftcpxfft cpxfile width length xpix ypix'
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
      allocate (tempx(ranfftx),tempxover(ranfftx*novr))
      call sfftw_plan_dft_1d(iplanwidth, ranfftx, tempx, tempx, -1, 64)
      call sfftw_plan_dft_1d(iplanwidthinv, ranfftx*novr, tempxover, tempxover, 1, 64)

      do i=1,20
         if(2**i.ge.length)go to 20
      end do
20      ranffty=2**i
      allocate (tempy(ranffty),tempyover(ranffty*novr))
      call sfftw_plan_dft_1d(iplanlength, ranffty, tempy, tempy, -1, 64)
      call sfftw_plan_dft_1d(iplanlengthinv, ranffty*novr, tempyover, tempyover, 1, 64)

!      print *,'ranfftx ranffty ',ranfftx, ranffty
!c    
!c    open input file
!c    
      open(21,file=name,access='direct',recl=width*length*8)
      read(21,rec=1)array

!c  first shift across
      ishift=floor(xpix)
      frac=xpix-ishift
      ifrac=nint(frac*novr)
      print *,'ishift frac ifrac ',ishift,frac,ifrac

      !$OMP parallel do private(tempx,tempxover,j) &
      !$OMP shared(length,width,iplanwidth,ranfftx,novr,iplanwidthinv) &
      !$OMP shared(array,ishift,frac,ifrac)
      do i=1,length
         tempx=cmplx(0.,0.)
         tempx(1:width)=array(1:width,i)
         call sfftw_execute_dft(iplanwidth,tempx,tempx)
         tempxover=cmplx(0.,0.)
         tempxover(1:ranfftx/2)=tempx(1:ranfftx/2)
         tempxover(ranfftx*novr-ranfftx/2+1:ranfftx*novr)=tempx(ranfftx/2+1:ranfftx)
         call sfftw_execute_dft(iplanwidthinv,tempxover,tempxover)
         tempx(:)=cmplx(0.,0.)
         if(ishift.ge.0)then
            do j=2,width-ishift-1
               !print *,j,width,ishift,ifrac,j*4-3-ifrac
               tempx(j+ishift)=tempxover(j*novr-novr+1-ifrac)/ranfftx
            end do
         else
            do j=2-ishift,width-1
               tempx(j+ishift)=tempxover(j*novr-novr+1-ifrac)/ranfftx
            end do
         end if
         array(:,i)=tempx(1:width)
      end do
      !$OMP end parallel do

!c  now down
      ishift=floor(ypix)
      frac=ypix-ishift
      ifrac=nint(frac*novr)
      print *,'ishift frac ifrac ',ishift,frac,ifrac
      !$OMP parallel do private(tempy,tempyover,j) &
      !$OMP shared(length,width,iplanlength,ranffty,novr,iplanlengthinv) &
      !$OMP shared(array,ishift,frac,ifrac)
      do i=1,width
         tempy=cmplx(0.,0.)
         tempy(1:length)=array(i,1:length)
         call sfftw_execute_dft(iplanlength,tempy,tempy)
         tempyover=cmplx(0.,0.)
         tempyover(1:ranffty/2)=tempy(1:ranffty/2)
         tempyover(ranffty*novr-ranffty/2+1:ranffty*novr)=tempy(ranffty/2+1:ranffty)
         call sfftw_execute_dft(iplanlengthinv,tempyover,tempyover)
         tempy(:)=cmplx(0.,0.)
         if(ishift.ge.0)then
            do j=2,length-ishift-1
               !print *,j,width,ishift,ifrac,j*4-3-ifrac
               tempy(j+ishift)=tempyover(j*novr-novr+1-ifrac)/ranffty
            end do
         else
            do j=2-ishift,length-1
               tempy(j+ishift)=tempyover(j*novr-novr+1-ifrac)/ranffty
            end do
         end if
         array(i,:)=tempy(1:length)
      end do
      !$OMP end parallel do

      write(21,rec=1)array

    end program shiftcpxfft


