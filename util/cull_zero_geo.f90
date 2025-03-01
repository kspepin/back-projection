  !c  cull_zero_geo - remove blank geo files from geolist
  

  complex*8, allocatable :: in(:,:),out(:),inlooks(:,:),zeros(:)
  character*200 infile, outfile, str, filelist, fin(10000), filein
  integer*8 filelen, reclen, len, lines

  if (iargc().lt.2)then
     print *,'usage: cull_zero_geo filelist(cpx size) len '
     stop
  end if

  call getarg(1,filelist)
  call getarg(2,str)
  read(str,*)len

  !c read in the input file list, containing geofiles to be analyzed
  open(21,file=filelist)
  do i=1,10000
     read(21,'(a)',end=11)fin(i)
!     print *,fin(i)
  end do
11 close(21)
  ngeos=i-1
  print *,'Input files: ',ngeos

  !c get file length
  lines=filelen(fin(1))/8/len
  write(*,*)'Lines in input file: ',lines!,fin(1),filelen(fin(1))

  allocate (in(len,lines))

  !c  loop over file list
  open(31,file='geolist.nonzero')
  open(32,file='geolist.zero')
  do ifile=1,ngeos
     filein=trim(fin(ifile))//' '

        open(21,file=trim(filein),access='stream')
           read(21)in
        close(21)

     qqsum = sum(cabs(in(1:10:len,1:10:lines)))
     print *,qqsum,' ',trim(filein)
     if(qqsum.gt.1.e-6)then
        write(31,*)trim(filein)
     else
        write(32,*)trim(filein)
     end if
!     do line=1,lines,10
!        do ipix=1,len,10
           !print *,line,ipix
!           qqsum=sum(cabs(in((ipix-1)*looksx+1:(ipix-1)*looksx+looksx,(line-1)*looksy+1:(line-1)*looksy+looksy))**2)
!        end do
!     end do

  end do
close(31)
end program
