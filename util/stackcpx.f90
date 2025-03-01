  !c  stackcpx - create a stacked complex file from a list of cpx files
  
  complex*8, allocatable :: in(:,:),out(:,:)
  character*100 outfile, str, filelist, infile
  integer*8 nbytes, filelen, len, lines

  if (iargc().lt.3)then
     print *,'usage: stackcpx filelist(cpx) outfile len'
     stop
  end if

  call getarg(1,filelist)
  call getarg(2,outfile)
  call getarg(3,str)
  read(str,*)len

  !c loop over filelist
  open(21,file=filelist)
  do i=1,10000
     read(21,*,end=11)infile
     if(i.eq.1)then
        nbytes=filelen(infile)
        lines=nbytes/len/8
        print *,'Lines in files: ',lines
        allocate (in(len,lines),out(len,lines))
        out=cmplx(0.,0.)
     end if

     open(31,file=infile,access='direct',recl=nbytes)
     read(31,rec=1)in
     close(31)
     out=out+in
  end do
11 close(21)
  nigrams=i-1
  print *,'Input files: ',nigrams

  open(22,file=outfile,access='direct',recl=nbytes)
  write(22,rec=1)out
  close(22)

end program
