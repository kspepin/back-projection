!c    igramstack - stack a set of igrams
!c        

program igramstack

      implicit none
      integer*4    width,length
      complex*8, allocatable :: array1(:,:), array2(:,:)
      complex*8, allocatable :: igram(:,:), amp(:,:)
      character*300 outfile, listfile, fin, f1(1000), f2(1000)
      character*100 str
      integer*4 i, j, intshift, nfiles

!c    **********  input parameters  **********
!c    
!c    enter input parameters
!c    
      if(iargc().lt.4)then
         print *,'Usage: igramstack igramfilelist outfile width length'
         call exit
      end if

      call getarg(1,listfile)
      call getarg(2,outfile)
      call getarg(3,str)
      read(str,*)width
      call getarg(4,str)
      read(str,*)length
 
!c    allocate arrays
      allocate(array1(width,length), array2(width,length), igram(width,length), amp(width,length))

!c read in the input file list
      open(21,file=listfile)
      do i=1,10000
         read(21,'(a)',end=11)fin
         fin=trim(adjustl(fin))
         !print *,trim(fin)
         f1(i)=fin(1:index(fin,'slc')+3)
         f2(i)=trim(fin(index(fin,'slc')+4:300))
         !read(fin(i),'(a,1x,a)')f1(i),f2(i)
!!$         print *,fin(i)
         !print *,trim(f1(i))
         !print *,trim(f2(i))
      end do
11    close(21)
      nfiles=i-1
      print *,'Input files: ',nfiles

!c  loop over the input files
      igram=cmplx(0.,0.)
      amp=cmplx(0.,0.)
      do i=1,nfiles
         !print *,f1(i)
         open(21,file=f1(i),access='direct',recl=width*length*8)
         read(21,rec=1)array1
         close(21)
         !print *,f2(i)
         open(21,file=f2(i),access='direct',recl=width*length*8)
         read(21,rec=1)array2
         close(21)
         igram=igram+array1*conjg(array2)
         amp=amp+cmplx(cabs(array1)**2,cabs(array2**2))
      end do
      igram=igram/nfiles
      amp=amp/nfiles
      amp=cmplx(sqrt(real(amp)),sqrt(aimag(amp)))
!      array=cmplx(sqrt(power),0.)

      open(21,file=trim(outfile)//'.int',access='direct',recl=width*length*8)
      write(21,rec=1)igram
      close(21)
      open(21,file=trim(outfile)//'.amp',access='direct',recl=width*length*8)
      write(21,rec=1)amp
      close(21)
      
    end program igramstack
