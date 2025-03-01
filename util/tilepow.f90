  !c  tilepow - create a tiled file from a list of complex files, take power looks
  
  use omp_lib

  complex*8, allocatable :: in(:,:),out(:),inlooks(:,:),zeros(:)
  character*200 infile, outfile, str, filelist, fin(10000), filein
  integer*8 filelen, reclen, len, lines

  if (iargc().lt.5)then
     print *,'usage: tilepow filelist(cpx size) outfile tiles_across len <xlooks=1> <ylooks=xlooks>'
     stop
  end if

  call getarg(1,filelist)
  call getarg(2,outfile)
  call getarg(3,str)
  read(str,*)nx
  call getarg(4,str)
  read(str,*)len
  looksx=1
  if (iargc().ge.5)then
     call getarg(5,str)
     read(str,*)looksx
  end if
  looksy=looksx
  if (iargc().ge.6)then
     call getarg(6,str)
     read(str,*)looksy
  end if

  !c read in the input file list, containing interferograms to be analyzed
  open(21,file=filelist)
  do i=1,10000
     read(21,'(a)',end=11)fin(i)
!     print *,fin(i)
  end do
11 close(21)
  nigrams=i-1
  print *,'Input files: ',nigrams

  !c get file length
!  lines=filelen(trim(fin(1)))/8/len
  lines=filelen(fin(1))/8/len
  write(*,*)'Lines in input file: ',lines,fin(1),filelen(fin(1))

  !c set output file params and open
  lenout=(len/looksx)
  linesout=(lines/looksy)
  print *,'Output tile size, tiled image length: ',lenout,linesout,lenout*nx
  ny=(nigrams-1)/nx+1
  print *,'Tile matrix size across, down: ',nx,ny,nigrams
  open(22,file=outfile,access='direct',recl=lenout*8)
  allocate(in(len,lines),out(lenout),inlooks(lenout,linesout),zeros(lenout))
  zeros=0.0
  reclen=len*lines*8

  !c  loop over file list
  do ifile=1,nx*ny !nigrams
     filein=trim(fin(ifile))//' '
!     print *,'on file ',trim(fin(ifile))
!     print *,filein
!     print *,len,lines,reclen
     if(ifile.le.nigrams)then
        open(21,file=trim(filein),access='direct',recl=len*8)
        do line=1,lines
           read(21,rec=line)in(:,line)
        end do
        close(21)
     end if
     !print *,'file read'

     !c  take looks
     !$OMP parallel do private(ipix,qqsum) &
     !$OMP shared(linesout,lenout,in,looksx,looksy)
     do line=1,linesout
        do ipix=1,lenout
           !print *,line,ipix
           qqsum=sum(cabs(in((ipix-1)*looksx+1:(ipix-1)*looksx+looksx,(line-1)*looksy+1:(line-1)*looksy+looksy))**2)
!           qsum=0.0
!           do i=1,looksx
!              do j=1,looksy
!                 inlooks(ipix,line)=inlooks(ipix,line)+in((ipix-1)*looksx+i,(line-1)*looksy+j)
!                 qsum=qsum+cabs(in((ipix-1)*looksx+i,(line-1)*looksy+j))**2
!              end do
!           end do
           inlooks(ipix,line)=cmplx(sqrt(qqsum),0.0)
!           print *,qsum,qqsum
        end do
     end do
     !$OMP end parallel do
     !print *,'writing'
     do j=1,linesout  ! loop over records in output file
        jrec=((ifile-1)/nx)*linesout*nx+mod(ifile-1,nx)+1+(j-1)*nx
!        print *,linesout,j,jrec
        if(ifile.le.nigrams)then
           write(22,rec=jrec)inlooks(:,j)
        else
           write(22,rec=jrec)zeros
        end if
     end do
  end do

end program
