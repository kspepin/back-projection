!c  crossmul_commonband - cross multiply two files, one conjugated, form int and amp file
!c  like crossmul but apply common band filter from mocomp_shift files

      use omp_lib

      complex*8, allocatable:: in1(:,:),in2(:,:),igram(:,:),amp(:,:)
      complex*8, allocatable:: up1(:,:),up2(:,:),inline1(:),inline2(:)
      complex*8, allocatable:: igramacc(:),ampacc(:),igramtemp(:),amptemp(:)
      real*4, allocatable:: filter(:),filtshift(:)
      character*100 fin1,fin2,str,figram,famp,fshift1,fshift2
      integer*8 nbytes,filelen

      real*4 shift1(1000000),shift2(1000000)

      real*4, allocatable :: plannnnf(:),plannnni(:)  ! for fft upsampling
      integer*8 iplannnnf,iplannnni

      !$omp parallel
      n=omp_get_num_threads()
      !$omp end parallel
      print *, 'Max threads used: ', n

      if(iargc().lt.5)then
         write(*,*)'usage: crossmul_commonband infile1 infile2 outintfile outampfile length '
         write(*,*)'mmocomp_shift1 mocomp_shift2 fs bw <valid_lines> <scale=1> <looksac> <looksdn>'
         print *,'scale is multiplied by each scene to prevent overflow'
         stop
      end if

      call getarg(1,fin1)
      call getarg(6,fshift1)
      call getarg(7,fshift2)
      call getarg(8,str)
      read(str,*)fs
      call getarg(9,str)
      read(str,*)bw

      call getarg(5,str)
      read(str,*)na
      looksac=1
      if(iargc().ge.12)then
         call getarg(12,str)
         read(str,*)looksac
      end if
      looksdn=looksac
      if(iargc().ge.13)then
         call getarg(13,str)
         read(str,*)looksdn
      end if
      open(21,file=fin1,form='unformatted',access='direct',recl=na*8*looksdn)
      nbytes=filelen(trim(fin1))
      nd=nbytes/8/na
      write(*,*)'Lines in file: ',nd
      call getarg(2,fin2)
      if(trim(fin1).ne.trim(fin2))then
         open(22,file=fin2,form='unformatted',access='direct',recl=na*8*looksdn)
      end if
      call getarg(3,figram)
      call getarg(4,famp)
      nvalid=nd
      if(iargc().ge.10)then
         call getarg(10,str)
         read(str,*)nvalid
      end if
      scale=1.0
      if(iargc().ge.11)then
         call getarg(11,str)
         read(str,*)scale
      end if
      print *,'Interferogram width: ',na/looksac

!c  get ffts lengths for upsampling
      do i=1,16
         nnn=2**i
         if(nnn.ge.na)go to 11
      end do
11    print *,'FFT length: ',nnn
      call fftw_f77_create_plan(iplannnnf,nnn,-1,8)
      call fftw_f77_create_plan(iplannnni,nnn*2,1,8)

!c  create the common band filter
      open(11,file=fshift1)
      do i=1,1000000
         read(11,*,end=12)shift1(i)
      end do
12    close(11)
      open(11,file=fshift2)
      do i=1,1000000
         read(11,*,end=13)shift2(i)
      end do
13    close(11)
      deltaf1=shift1(int(i/2))
      deltaf2=shift2(int(i/2))
      fr=(deltaf1+deltaf2)/2
      br=bw-abs(deltaf1-deltaf2)

!c  design the filter
      nfilt=nnn
      allocate(filter(nfilt),filtshift(nfilt))
      filter=0
      ifilt0=(fr+fs/2-br/2)/fs*nfilt
      ifilt1=(fr+fs/2+br/2)/fs*nfilt
      print *,'deltaf1 deltaf2 fr br ifilt0 ifilt1',deltaf1,deltaf2,fr,br,ifilt0,ifilt1
      do i=ifilt0,ifilt1
         k=i
         if(k.lt.1)k=i+nfilt
         if(k.gt.nfilt)k=i-nfilt
         filter(k)=1
      end do
      do i=ifilt0,ifilt0+nfilt/10
         k=i
         if(k.lt.1)k=i+nfilt
         if(k.gt.nfilt)k=i-nfilt
         filter(k)=(1.-cos((i-ifilt0)/float(nfilt/10)*3.14159))/2.
      end do
      do i=ifilt1-nfilt/10,ifilt1
         k=i
         if(k.lt.1)k=i+nfilt
         if(k.gt.nfilt)k=i-nfilt
         filter(k)=(1.-cos((ifilt1-i)/float(nfilt/10)*3.14159))/2.
      end do
      !  apply the fft shift
      filtshift(1:nfilt/2)=filter(nfilt/2+1:nfilt)
      filtshift(nfilt/2+1:nfilt)=filter(1:nfilt/2)
      filter=filtshift

      open(11,file='commonbandfilter.out')
      do i=1,nfilt
         write(11,*)filter(i)
      end do
      close(11)

      open(32,file=figram,form='unformatted',access='direct',recl=na/looksac*8)
      open(33,file=famp,form='unformatted',access='direct',recl=na/looksac*8)

      !$omp parallel do private(in1,in2,up1,up2,inline1,inline2,igram,amp) &
      !$omp private(igramacc,ampacc,igramtemp,amptemp,j,k,i,line,plannnnf,plannnni) &
      !$omp shared(nvalid,looksdn,scale,na,nnn,iplannnnf,iplannnni) &
      !$omp shared(looksac,fin1,fin2,filter)

      do line=1,nvalid/looksdn
         if(mod(line,1000).eq.0)print *,line
         !c  allocate the local arrays
         allocate (in1(na,looksdn),in2(na,looksdn),igram(na*2,looksdn),amp(na*2,looksdn))
         allocate (igramacc(na),ampacc(na),igramtemp(na/looksac),amptemp(na/looksac))
         allocate (up1(nnn*2,looksdn), up2(nnn*2,looksdn), inline1(nnn), inline2(nnn))
         allocate (plannnnf(nnn*4+15),plannnni(nnn*2*4+15))

!c     read in lines
         read(21,rec=line,err=99)in1
         if(fin1.ne.fin2)then
            read(22,rec=line,err=99)in2
         else
            in2=in1
         end if

!c     cross-multiply and save amplitudes
         in1=in1*scale
         in2=in2*scale

         up1=cmplx(0.,0.)  ! upsample file 1
         do i=1,looksdn
            inline1(1:na)=in1(:,i)
            inline1(na+1:nnn)=cmplx(0.,0.)
            call fftw_f77_one(iplannnnf,inline1,plannnnf)
            inline1=inline1*filter
            up1(1:nnn/2,i)=inline1(1:nnn/2)
            up1(2*nnn-nnn/2+1:2*nnn,i)=inline1(nnn/2+1:nnn)
            call fftw_f77_one(iplannnni,up1(1,i),plannnni)
         end do
         up1=up1/nnn

         up2=cmplx(0.,0.)  ! upsample file 2
         do i=1,looksdn
            inline2(1:na)=in2(:,i)
            inline2(na+1:nnn)=cmplx(0.,0.)
            call fftw_f77_one(iplannnnf,inline2,plannnnf)
            inline2=inline2*filter
            up2(1:nnn/2,i)=inline2(1:nnn/2)
            up2(2*nnn-nnn/2+1:2*nnn,i)=inline2(nnn/2+1:nnn)
            call fftw_f77_one(iplannnni,up2(1,i),plannnni)
         end do
         up2=up2/nnn

         igram(1:na*2,:)=up1(1:na*2,:)*conjg(up2(1:na*2,:))
         amp(1:na*2,:)=cmplx(cabs(up1(1:na*2,:))**2,cabs(up2(1:na*2,:))**2)
!c  reclaim the extra two across looks first
         do j=1,na
            igram(j,:) = igram(j*2-1,:)+igram(j*2,:)
            amp(j,:) = amp(j*2-1,:)+amp(j*2,:)
         end do

!c     looks down 
         igramacc=sum(igram(1:na,:),2)
         ampacc=sum(amp(1:na,:),2)

!c     looks across
         do j=0,na/looksac-1
            igramtemp(j+1)=cmplx(0.,0.)
            amptemp(j+1)=cmplx(0.,0.)
            do k=1,looksac
               igramtemp(j+1)=igramtemp(j+1)+igramacc(j*looksac+k)
               amptemp(j+1)=amptemp(j+1)+ampacc(j*looksac+k)
            end do
            amptemp(j+1)=cmplx(sqrt(real(amptemp(j+1))),sqrt(aimag(amptemp(j+1))))
         end do

         write(32,rec=line)igramtemp
         write(33,rec=line)amptemp
 99   continue

         deallocate (in1, in2, up1, up2, igramtemp, amptemp, igramacc, ampacc, inline1, inline2, igram, amp, plannnnf,plannnni)
      end do
      !$omp end parallel do

      end


