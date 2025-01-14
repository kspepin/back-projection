!c  deplane - remove a plane to deramp an unwrapped image

  real*4, allocatable :: unwrapped(:,:), flat(:,:), phase(:,:)
  character*300 ufile,demfile,outfile,locationfile,str,intfile
  complex, allocatable :: igram(:,:)

  if(iargc().lt.4)then
     print *,'Usage: deplane unwrapped_file outfile len lines'
     stop
  end if

  call getarg(1,ufile)
  call getarg(2,outfile)
  call getarg(3,str)
  read(str,*)len
  call getarg(4,str)
  read(str,*)lines

  allocate (unwrapped(2*len,lines),phase(len,lines),flat(len,lines))

!c  read in the file
  open(21,file=ufile,access='direct',recl=len*8*lines)
  read(21,rec=1)unwrapped
  close(21)

!c  set up the regression
  do i=1,lines
     phase(:,i)=unwrapped(1+len:2*len,i)
  end do

!c regression
  call fitplane(phase,flat,len,lines)

!c save regressed file
  open(21,file=outfile,access='direct',recl=len*8)
  do i=1,lines
     write(21,rec=i)unwrapped(1:len,i),flat(:,i)
  end do
  close(21)

end program
