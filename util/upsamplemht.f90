!c  upsamplemht - upsample an mht file linearly

      character*360 infile, outfile
      character*14 str, str2
      real*4, allocatable :: in(:,:),out(:,:)
      integer*8 nbytes, filelen

      if(iargc().lt.6)then
         print *,'Usage: upsamplemht infile outfile length lines outlength outlines'
         stop
      end if

      call getarg(1,infile)
      call getarg(2,outfile)
      call getarg(3,str)
      read(str,*)len
      call getarg(4,str)
      read(str,*)lines
      call getarg(5,str)
      read(str,*)lenout
      call getarg(6,str)
      read(str,*)linesout

      allocate (in(len*2,lines),out(lenout*2,linesout))
      kx=lenout/len
      ky=linesout/lines
      print *,'Upsample factors x, y: ',kx,ky

!c  open input and output files
      open(21,file=infile,access='stream')
      open(31,file=outfile,access='stream')
      read(21)in
      out=0.

!c  loop over input lines
      do i=1,lines-1
         ! interpolate across
         do j=1,len-1
            do k=1,kx
               index=(j-1)*kx+k
               out(index,i)=in(j,i)+(in(j+1,i)-in(j,i))*float(k-1)/float(kx)
               out((j-1)*kx+k,kx)=in(j,i+1)+(in(j+1,i+1)-in(j,i+1))*float(k-1)/float(kx)
               out(index+lenout,i)=in(j+len,i)+(in(j+1+len,i)-in(j+len,i))*float(k-1)/float(kx)
               out((j-1)*kx+k+lenout,kx)=in(j+len,i+1)+(in(j+1+len,i+1)-in(j+len,i+1))*float(k-1)/float(kx)
               !print *,idata(j,1),idata(j+1,1),outdata((j-1)*ifactor+k,1)
               !print *,index,outdata(index,1)
            end do
         end do
      end do

      do i=lines-1,1,-1
         !interpolate down
         do k=1,ky
            out(:,(i-1)*ky+k)=out(:,i)+(out(:,i+1)-out(:,i))*float(k)/float(ky)
!            out(len*kx+1:len*kx*2,k)= &
!                   out(len*kx+1:len*kx*2,i)+ &
!                   (out(len*kx+1:len*kx*2,ky)- &
!                   out(len*kx+1:len*kx*2,i))*float(k-1)/float(ky)
         end do

         
         !  write interpolated data
         !do k=1,ifactor
         !   index=(i-1)*ifactor+k
         !   !print *,index
         !   write(31,rec=index)outdata(:,1)
         !end do
         !print *,outdata(:,1)
      end do
!c  write last line
      !write(31,rec=(ilength-1)*ifactor+1)outdata(:,ifactor)
      write(31)out

      close(21)
      close(31)

      end
