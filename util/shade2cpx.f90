!c  shade2cpx - convert an i*2 image to shaded relief in complex form

      integer*2, allocatable :: i2(:)
      real, allocatable :: shade(:)
      complex, allocatable :: c(:),out(:)
      character*60 filei2,filecpx,filerg,str
      integer stat,statb(13)

      if(iargc().lt.3)then
         print *,'Usage:  shade2cpx i2file cpxfile length <shadescale=1>'
         stop
      end if

      call getarg(1,filei2)
      call getarg(2,filecpx)
      call getarg(3,str)
      read(str,*)len
      scale=1.
      if(iargc().ge.4)then
         call getarg(4,str)
         read(str,*)scale
      end if

!c  file size
      ierr=stat(filei2,statb)
      linesi2=statb(8)/len/2
      print *,'Lines in i2 file: ',linesi2

      allocate(i2(len))
      allocate(c(len))
      allocate(out(len))
      allocate(shade(len))

      open(21,file=filei2,access='direct',recl=len*2)
      open(22,file=filecpx,access='direct',recl=len*8)

      do i=1,linesi2
         read(21,rec=i)i2
!c  shade this line
         do j=2,len-1
            shade(j)=(-i2(j-1)+i2(j+1))*scale+100
            if(shade(j).lt.0.)shade(j)=0.
            if(shade(j).gt.200.)shade(j)=200.
         end do
         shade(1)=0
         shade(len)=0

         do j=1,len
            out(j)=cmplx(shade(j),0.)
         end do
         write(22,rec=i)out
      end do

      end
