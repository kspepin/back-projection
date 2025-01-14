! flattengeo - flatten a geo image using an unwrapped image

      real*4, allocatable:: unw(:,:),phase(:,:)
      complex*8, allocatable:: geo(:,:),out(:,:)

      character*300 fgeo,funw,fout,str
      integer*8 nbytes,filelen

      if(iargc().lt.4)then
         write(*,*)'usage: flattengeo geofile unwfile outfile length'
         stop
      end if

      call getarg(1,fgeo)
      call getarg(2,funw)
      call getarg(3,fout)
      call getarg(4,str)
      read(str,*)len
      nbytes=filelen(fgeo)
!      nbytes=filelen(trim(fin))
      lines=nbytes/8/len
      write(*,*)'Lines in file: ',lines

      allocate(unw(len*2,lines),out(len,lines),geo(len,lines),phase(len,lines))

      open(21,file=fgeo,form='unformatted',access='direct',recl=len*lines*8)
      open(22,file=funw,form='unformatted',access='direct',recl=len*lines*8)
      open(23,file=fout,form='unformatted',access='direct',recl=len*lines*8)

      read(21,rec=1)geo
      read(22,rec=1)unw

      out=geo*cmplx(cos(unw(len+1:len*2,:)),-sin(unw(len+1:len*2,:)))

      write(23,rec=1)out
      close(21)
      close(22)
      close(23)

      end


