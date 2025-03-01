! synth_igram - synthetic interferogram from displacement solution

      real*4, allocatable:: unw(:,:),disp1(:,:),disp2(:,:)

      character*300 fdisp,funw,fout,str

      if(iargc().lt.6)then
         write(*,*)'usage: synth_igram displacementfile unwfile length lines step1 step2'
         stop
      end if

      call getarg(1,fdisp)
      call getarg(2,funw)
      call getarg(3,str)
      read(str,*)len
      call getarg(4,str)
      read(str,*)lines
      call getarg(5,str)
      read(str,*)istep1
      call getarg(6,str)
      read(str,*)istep2

      allocate(unw(len*2,lines),disp1(len*2,lines),disp2(len*2,lines))

      open(21,file=fdisp,form='unformatted',access='direct',recl=len*lines*8)
      open(22,file=funw,form='unformatted',access='direct',recl=len*lines*8)

      if(istep1.eq.1)then
         disp1=0.
      else
         read(21,rec=istep1-1)disp1
      end if
      read(21,rec=istep2-1)disp2

      unw(1:len,:)=disp2(1:len,:)
      unw(len+1:len*2,:)=disp2(len+1:len*2,:)-disp1(len+1:len*2,:)

      write(22,rec=1)unw
      close(21)
      close(22)

      end


