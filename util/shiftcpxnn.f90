!c    shiftcpxnn - shift an image across and down (positive sense of args)
!c        use nearest neighbor interpolation

program shiftcpxnn

      implicit none
      integer*4    width,length
      complex*8, allocatable :: array(:,:)
      complex*8, allocatable :: tempx(:),tempy(:),cpxphasex(:),cpxphasey(:)
      character*300 name
      character*100 str
      integer*4 i, j, intshift
      real*8 xpix, ypix, frac
      print *

!c    **********  input parameters  **********
!c    
!c    enter input parameters
!c    
      if(iargc().lt.5)then
         print *,'Usage: shiftcpxnn cpxfile width length xpix ypix'
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
      allocate (tempx(width))
      allocate (tempy(length))
!c    
      open(21,file=name,access='direct',recl=width*length*8)
      read(21,rec=1)array

!c  first shift across
      intshift=nint(xpix)
      print *,'intshift ',intshift
      do i=1,length
         tempx=cmplx(0.,0.)
         if(intshift.ge.0)then
            do j=2,width-intshift
               tempx(j+intshift)=array(j,i)
            end do
         else
            do j=2-intshift,width
               tempx(j+intshift)=array(j,i)
            end do
         end if
         array(:,i)=tempx
      end do

!c  now down
      intshift=nint(ypix)
      print *,'intshift frac ',intshift
      do i=1,width
         tempy=cmplx(0.,0.)
         if(intshift.ge.0)then
            do j=2,length-intshift
               tempy(j+intshift)=array(i,j)
            end do
         else
            do j=2-intshift,length
               tempy(j+intshift)=array(i,j)
            end do
         end if
         array(i,:)=tempy
      end do

      write(21,rec=1)array

    end program shiftcpxnn
