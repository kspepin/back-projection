c  cpxlooks -  average complex looks
      complex a(20480),b(20480),sum,pha,phd
      character*30 fin,fout
      integer statb(13),fstat

      if(iargc().lt.4)then
         write(*,*)'usage: cpxlooks infile outfile length looksac <looksdn>',
     &         ' <ph-ac> <ph-dn>'
         stop
      end if

      call getarg(1,fin)
      call getarg(3,fout)
      read(fout,*)na
      open(21,file=fin,form='unformatted',access='direct',recl=na*8)
      ierr=fstat(21,statb)
      nd=statb(8)/8/na
      write(*,*)'Lines in file: ',nd
      call getarg(4,fout)
      read(fout,*)la
      if(iargc().ge.5)then
         call getarg(5,fout)
         read(fout,*)ld
      else
         ld=la
      end if
      if(iargc().ge.6)then
         call getarg(6,fout)
         read(fout,*)pa
      else
         pa=0.
      end if
      if(iargc().ge.7)then
         call getarg(7,fout)
         read(fout,*)pd
      else
         pd=0.
      end if
      call getarg(2,fout)
      open(22,file=fout,form='unformatted',access='direct',recl=na/la*8)
      

      pha=cmplx(cos(pa),sin(pa))
      phd=cmplx(cos(pd),sin(pd))

      lineout=0
      do line=1,nd,ld
         if(mod(line,1000).eq.1)write(*,*)line
         lineout=lineout+1
         do j=1,na
            b(j)=cmplx(0.,0.)
         end do

c  take looks down
         do i=0,ld-1
            read(21,rec=line+i,err=99)(a(k),k=1,na)
            do j=1,na
               b(j)=b(j)+a(j)*pha**j*phd**(line+i)
            end do
         end do
c  take looks across
         jpix=0
         do j=1,na,la
            jpix=jpix+1
            sum=cmplx(0.,0.)
            do k=0,la-1
               sum=sum+b(j+k)
            end do
            b(jpix)=sum
         end do
         write(22,rec=lineout)(b(k),k=1,na/la)
      end do
 99   continue
      end

