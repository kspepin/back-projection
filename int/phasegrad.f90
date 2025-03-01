! phasegrad - compute (phase) gradient of mht image

      real*4, allocatable:: in(:,:),out(:,:)
      character*300 fin,fout,str
      integer*8 nbytes,filelen

      if(iargc().lt.3)then
         write(*,*)'usage: phasegrad infile outfile length'
         stop
      end if

      call getarg(1,fin)
      call getarg(2,fout)
      call getarg(3,str)
      read(str,*)len
      nbytes=filelen(fin)
!      nbytes=filelen(trim(fin))
      lines=nbytes/8/len
      write(*,*)'Lines in file: ',lines

      allocate(in(len*2,lines),out(len*2,lines))

      open(21,file=fin,form='unformatted',access='direct',recl=len*lines*8)
      open(22,file=fout,form='unformatted',access='direct',recl=len*lines*8)

      read(21,rec=1)in
      out=0.

! across differences
      do line=1,lines
         do i=2,len
            out(i*2-1,line)=abs(in(i+len,line)-in(i-1+len,line))
         end do
      end do
! down differences
      do line=2,lines
         do i=1,len
            out(i*2,line)=abs(in(i+len,line)-in(i+len,line-1))
         end do
      end do

      write(22,rec=1)out
      close(21)
      close(22)

      end


