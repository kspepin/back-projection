!c  efflooksimage - create an image of effective looks

      implicit none
      complex*8, allocatable :: array(:,:)
      real*4, allocatable :: sumsq(:,:), sum4th(:,:)
      integer*4  width, length, ibox,i, j, ibox2
      real*4 effsq, eff4th
      character*300 infile,outfile,c

      if(iargc().lt.5)then
         print *,'usage: efflooksimage infile outfile width length boxsize'
         stop
      end if
      call getarg(1,infile)
      call getarg(2,outfile)
      call getarg(3,c)
      read(c,*)width
      call getarg(4,c)
      read(c,*)length
      call getarg(5,c)
      read(c,*)ibox

!c  allocations
      allocate(array(width,length),sumsq(width,length),sum4th(width,length))

!c   open the input and output files
      open(unit=10,file=infile,access='direct',form='unformatted',recl=8*width*length)
      open(unit=11,file=outfile,access='direct',form='unformatted',recl=8*width*length)

      read(10,rec=1)array
      close(10)

!c  get the 2nd and fourth moment generators
      sumsq=cabs(array)**2
      sum4th=sumsq**2
      array=cmplx(0.,0.)

!c  form eff looks estimates
      ibox2=ibox/2
      do j=ibox2+1,length-ibox2
         if(mod(i,100).eq.0)print *,i
         do i=ibox2+1,width-ibox2
            effsq=sum(sumsq(i-ibox2:i+ibox2,j-ibox2:j+ibox2))/ibox/ibox
            eff4th=sum(sum4th(i-ibox2:i+ibox2,j-ibox2:j+ibox2))/ibox/ibox
            array(i,j)=cmplx(effsq**2/(eff4th-effsq**2),0.)
         end do
      end do

      write(11,rec=1)array

    end program

!!$
!!$    do kk=1,len
!!$            sum(kk)=sum(kk)/n(kk)
!!$            sumsq(kk)=sumsq(kk)/n(kk)
!!$            eff(kk)=cmplx(sum(kk)**2/(sumsq(kk)-sum(kk)**2),0.)
!!$         end do
!!$         write(11,rec=i)(eff(k),k=1,len)
!!$      end do
!!$ 20   continue
!!$      do k=i,nlines
!!$         write(11,rec=k)(0.,kk=1,len*2)
!!$      end do
!!$
!!$      end
