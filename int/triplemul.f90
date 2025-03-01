!c  triplemul - cross multiply three files to form closure triplet, with both int and amp files
!
!   note: use one of the interferogram pairs for a proxy cc file

      use omp_lib

      complex*8, allocatable:: in1(:,:),in2(:,:),in3(:,:),igram(:,:),amp(:,:),cc(:)
      complex*8, allocatable:: igram12(:,:),igram23(:,:),igram31(:,:)
      complex*8, allocatable:: amp12(:,:),amp23(:,:),amp31(:,:)
      complex*8, allocatable:: up1(:,:),up2(:,:),up3(:,:),inline1(:),inline2(:),inline3(:)
      complex*8, allocatable:: igramacc(:),ampacc(:),igramtemp(:),amptemp(:)
      complex*8, allocatable:: igram12acc(:),igram23acc(:),igram31acc(:),amp12acc(:),amp23acc(:),amp31acc(:)
      complex*8, allocatable:: igram12temp(:),igram23temp(:),igram31temp(:),amp12temp(:),amp23temp(:),amp31temp(:)
      character*300 fin1,fin2,fin3,str,figram,famp,fcc
      integer*8 nbytes,filelen
      character(1000) Replace_Text

      real*4, allocatable :: plannnnf(:),plannnni(:)  ! for fft upsampling
      integer*8 iplannnnf,iplannnni

      !$omp parallel
      n=omp_get_num_threads()
      !$omp end parallel
      print *, 'Max threads used: ', n

      if(iargc().lt.6)then
         print *,'usage: triplemul infile1 infile2 infile3 &
              outintfile outampfile length <valid_lines> &
              <scale=1> <looksac> <looksdn>'
         print *,'scale is multiplied by each scene to prevent overflow, enter <= 0 for autoscale'
         stop
      end if

      call getarg(1,fin1)
      call getarg(6,str)
      read(str,*)na
      looksac=1
      if(iargc().ge.9)then
         call getarg(9,str)
         read(str,*)looksac
      end if
      looksdn=looksac
      if(iargc().ge.10)then
         call getarg(10,str)
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
      call getarg(3,fin3)
      if(trim(fin1).ne.trim(fin3))then
         open(23,file=fin3,form='unformatted',access='direct',recl=na*8*looksdn)
      end if
      call getarg(4,figram)
      call getarg(5,famp)
      fcc=famp
      fcc=Replace_Text(fcc,'amp','cc')
!      print *,'Implied fcc: ',fcc
      nvalid=nd
      if(iargc().ge.7)then
         call getarg(7,str)
         read(str,*)nvalid
      end if
      scale=0.0
      if(iargc().ge.8)then
         call getarg(8,str)
         read(str,*)scale
      end if
      print *,'Interferogram width: ',na/looksac

! if desired autoscale
      if(scale.le.1.e-20)then
         allocate (in1(na,looksdn))
         ampsum=0.
         nsum=0
         do line=100,nvalid/looksdn-100,100
            read(21,rec=line)in1
            do i=100,na-100,100
               ampsum=ampsum+cabs(in1(i,1))
               nsum=nsum+1
            end do
         end do
         scale=1/(ampsum/nsum)
         deallocate (in1)
         print *,'Scale calculated: ',scale
      end if

!c  get ffts lengths for upsampling
      do i=1,24
         nnn=2**i
         if(nnn.ge.na)go to 11
      end do
11    print *,'FFT length: ',nnn
      call fftw_f77_create_plan(iplannnnf,nnn,-1,8)
      call fftw_f77_create_plan(iplannnni,nnn*2,1,8)

      open(32,file=figram,form='unformatted',access='direct',recl=na/looksac*8)
      open(33,file=famp,form='unformatted',access='direct',recl=na/looksac*8)
      open(34,file=fcc,form='unformatted',access='direct',recl=na/looksac*8)

      !$omp parallel do private(in1,in2,in3,up1,up2,up3,inline1,inline2,inline3,igram,amp) &
      !$omp private(igramacc,ampacc,igramtemp,amptemp,j,k,i,line,plannnnf,plannnni) &
      !$omp private(igram12acc,igram23acc,igram31acc,igram12temp,igram23temp,igram31temp) &
      !$omp private(amp12acc,amp23acc,amp31acc,amp12temp,amp23temp,amp31temp,cc) &
      !$omp private(igram12,igram23,igram31,amp12,amp23,amp31) &
      !$omp shared(nvalid,looksdn,scale,na,nnn,iplannnnf,iplannnni) &
      !$omp shared(looksac,fin1,fin2,fin3,fcc)

      do line=1,nvalid/looksdn
         if(mod(line,1000).eq.0)print *,line
         !c  allocate the local arrays
         allocate (in1(na,looksdn),in2(na,looksdn),in3(na,looksdn),igram(na*2,looksdn),amp(na*2,looksdn))
         allocate (igram12(na*2,looksdn),amp12(na*2,looksdn))
         allocate (igram23(na*2,looksdn),amp23(na*2,looksdn))
         allocate (igram31(na*2,looksdn),amp31(na*2,looksdn))
         allocate (igramacc(na),ampacc(na),igramtemp(na/looksac),amptemp(na/looksac))
         allocate (igram12acc(na),amp12acc(na),igram12temp(na/looksac),amp12temp(na/looksac),cc(na/looksac))
         allocate (igram23acc(na),amp23acc(na),igram23temp(na/looksac),amp23temp(na/looksac))
         allocate (igram31acc(na),amp31acc(na),igram31temp(na/looksac),amp31temp(na/looksac))
         allocate (up1(nnn*2,looksdn), up2(nnn*2,looksdn), up3(nnn*2,looksdn), inline1(nnn), inline2(nnn),inline3(nnn))
         allocate (plannnnf(nnn*4+15),plannnni(nnn*2*4+15))

!c     read in lines
         read(21,rec=line,err=98)in1
         if(fin1.ne.fin2)then
            read(22,rec=line,err=98)in2
         else
            in2=in1
         end if
         if(fin1.ne.fin3)then
            read(23,rec=line,err=98)in3
         else
            in3=in1
         end if
98       continue
!c     cross-multiply and save amplitudes
         in1=in1*scale
         in2=in2*scale
         in3=in3*scale

         up1=cmplx(0.,0.)  ! upsample file 1
         do i=1,looksdn
            inline1(1:na)=in1(:,i)
            inline1(na+1:nnn)=cmplx(0.,0.)
            call fftw_f77_one(iplannnnf,inline1,plannnnf)
            up1(1:nnn/2,i)=inline1(1:nnn/2)
            up1(2*nnn-nnn/2+1:2*nnn,i)=inline1(nnn/2+1:nnn)
            call fftw_f77_one(iplannnni,up1(1,i),plannnni)
         end do
         up1=up1/nnn/2.

         up2=cmplx(0.,0.)  ! upsample file 2
         do i=1,looksdn
            inline2(1:na)=in2(:,i)
            inline2(na+1:nnn)=cmplx(0.,0.)
            call fftw_f77_one(iplannnnf,inline2,plannnnf)
            up2(1:nnn/2,i)=inline2(1:nnn/2)
            up2(2*nnn-nnn/2+1:2*nnn,i)=inline2(nnn/2+1:nnn)
            call fftw_f77_one(iplannnni,up2(1,i),plannnni)
         end do
         up2=up2/nnn/2.

         up3=cmplx(0.,0.)  ! upsample file 3
         do i=1,looksdn
            inline3(1:na)=in3(:,i)
            inline3(na+1:nnn)=cmplx(0.,0.)
            call fftw_f77_one(iplannnnf,inline3,plannnnf)
            up3(1:nnn/2,i)=inline3(1:nnn/2)
            up3(2*nnn-nnn/2+1:2*nnn,i)=inline3(nnn/2+1:nnn)
            call fftw_f77_one(iplannnni,up3(1,i),plannnni)
         end do
         up3=up3/nnn/2.
!         if(line.eq.500)print *,up1(500,1),up2(500,1),up3(500,1)

!c  2-file interferograms for three components
         igram12(1:na*2,:)=up1(1:na*2,:)*conjg(up2(1:na*2,:))
         amp12(1:na*2,:)=cmplx(cabs(up1(1:na*2,:))**2,cabs(up2(1:na*2,:))**2)
         igram23(1:na*2,:)=up2(1:na*2,:)*conjg(up3(1:na*2,:))
         amp23(1:na*2,:)=cmplx(cabs(up2(1:na*2,:))**2,cabs(up3(1:na*2,:))**2)
         igram31(1:na*2,:)=up3(1:na*2,:)*conjg(up1(1:na*2,:))
         amp31(1:na*2,:)=cmplx(cabs(up3(1:na*2,:))**2,cabs(up1(1:na*2,:))**2)
!c  reclaim the extra two across looks first
         do j=1,na
            igram12(j,:) = igram12(j*2-1,:)+igram12(j*2,:)
            amp12(j,:) = amp12(j*2-1,:)+amp12(j*2,:)
            igram23(j,:) = igram23(j*2-1,:)+igram23(j*2,:)
            amp23(j,:) = amp23(j*2-1,:)+amp23(j*2,:)
            igram31(j,:) = igram31(j*2-1,:)+igram31(j*2,:)
            amp31(j,:) = amp31(j*2-1,:)+amp31(j*2,:)
         end do
!         if(line.eq.500)print *,igram12(500,1),igram23(500,1),igram31(500,1)

!c     looks down 
         igram12acc=sum(igram12(1:na,:),2)
         amp12acc=sum(amp12(1:na,:),2)
         igram23acc=sum(igram23(1:na,:),2)
         amp23acc=sum(amp23(1:na,:),2)
         igram31acc=sum(igram31(1:na,:),2)
         amp31acc=sum(amp31(1:na,:),2)

!c     looks across
         do j=0,na/looksac-1
            igram12temp(j+1)=cmplx(0.,0.)
            amp12temp(j+1)=cmplx(0.,0.)
            igram23temp(j+1)=cmplx(0.,0.)
            amp23temp(j+1)=cmplx(0.,0.)
            igram31temp(j+1)=cmplx(0.,0.)
            amp31temp(j+1)=cmplx(0.,0.)
            do k=1,looksac
               igram12temp(j+1)=igram12temp(j+1)+igram12acc(j*looksac+k)
               amp12temp(j+1)=amp12temp(j+1)+amp12acc(j*looksac+k)
               igram23temp(j+1)=igram23temp(j+1)+igram23acc(j*looksac+k)
               amp23temp(j+1)=amp23temp(j+1)+amp23acc(j*looksac+k)
               igram31temp(j+1)=igram31temp(j+1)+igram31acc(j*looksac+k)
               amp31temp(j+1)=amp31temp(j+1)+amp31acc(j*looksac+k)
            end do
            amp12temp(j+1)=cmplx((real(amp12temp(j+1))),(aimag(amp12temp(j+1))))
            amp23temp(j+1)=cmplx((real(amp23temp(j+1))),(aimag(amp23temp(j+1))))
            amp31temp(j+1)=cmplx((real(amp31temp(j+1))),(aimag(amp31temp(j+1))))
!            amp12temp(j+1)=cmplx(sqrt(real(amp12temp(j+1))),sqrt(aimag(amp12temp(j+1))))
!            amp23temp(j+1)=cmplx(sqrt(real(amp23temp(j+1))),sqrt(aimag(amp23temp(j+1))))
!            amp31temp(j+1)=cmplx(sqrt(real(amp31temp(j+1))),sqrt(aimag(amp31temp(j+1))))
         end do

!!!!!!!!         amp(1:na*2,:)=cmplx(cabs(up1(1:na*2,:))**2,cabs(up2(1:na*2,:))**2)
!c  finally form the triplets
         igramtemp=igram12temp*igram23temp*igram31temp
         amptemp=cmplx(real(amp12temp)*real(amp23temp)*real(amp31temp),aimag(amp12temp)*aimag(amp23temp)*aimag(amp31temp))
         amptemp=cmplx(sqrt(real(amptemp)),sqrt(aimag(amptemp)))
!         amptemp=sqrt(amp12temp**2*amp23temp**2*amp31temp**2)
         cc=cabs(igram12temp)/sqrt(real(amp12temp)*aimag(amp12temp))

         write(32,rec=line)igramtemp
         write(33,rec=line)amptemp
         write(34,rec=line)cc

 99   continue

         deallocate (in1, in2, in3, up1, up2, up3, cc)
         deallocate (igram12temp, igram23temp, igram31temp, igramtemp)
         deallocate (igram12,igram23,igram31,amp12,amp23,amp31)
         deallocate (amp12temp, amp23temp, amp31temp, amptemp)
         deallocate (igram12acc, igram23acc, igram31acc, igramacc)
         deallocate (amp12acc, amp23acc, amp31acc, ampacc)
         deallocate (inline1, inline2, inline3, igram, amp, plannnnf,plannnni)
      end do
      !$omp end parallel do

      end


FUNCTION Replace_Text (s,text,rep)  RESULT(outs)
CHARACTER(*)        :: s,text,rep
CHARACTER(LEN(s)+100) :: outs     ! provide outs with extra 100 char len
INTEGER             :: i, nt, nr

outs = s ; nt = LEN_TRIM(text) ; nr = LEN_TRIM(rep)
DO
   i = INDEX(outs,text(:nt)) ; IF (i == 0) EXIT
   outs = outs(:i-1) // rep(:nr) // outs(i+nt:)
END DO
END FUNCTION Replace_Text
