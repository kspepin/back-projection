!c  regress unwrapped phase vs height to remove stratified atmosphere

  integer*2, allocatable :: dem(:,:)
  real*4, allocatable :: unwrapped(:,:),test(:,:)
  integer*4 loc(2,1000000)
  real*4 phase(1000000),height(1000000),poly(3)
  character*300 ufile,demfile,outfile,locationfile,str,intfile
  complex, allocatable :: igram(:,:)

  if(iargc().lt.6)then
     print *,'Usage: unwrapped_file outfile demfile locations_file len lines <intfile to regress>'
     stop
  end if

  call getarg(1,ufile)
  call getarg(2,outfile)
  call getarg(3,demfile)
  call getarg(4,locationfile)
  call getarg(5,str)
  read(str,*)len
  call getarg(6,str)
  read(str,*)lines
  if(iargc().ge.7)call getarg(7,intfile)

  allocate (unwrapped(2*len,lines), dem(len,lines), test(2*len,lines))
  if(iargc().ge.7)allocate (igram(len,lines))
!c  get the locations
  open(21,file=locationfile)
  do i=1,1000000
     read(21,*,end=99)loc(1,i),loc(2,i)
  end do
99 nlocs=i-1
!c  print *,'Locations found: ',nlocs
  close(21)

!c  read in the files
  open(21,file=ufile,access='direct',recl=len*8*lines)
  read(21,rec=1)unwrapped
  close(21)
  open(21,file=demfile,access='direct',recl=len*2*lines)
  read(21,rec=1)dem
  close(21)
  if(iargc().ge.7)then
     open(21,file=intfile,access='direct',recl=len*8*lines)
     read(21,rec=1)igram
     close(21)
  end if

!c  set up the regression
  do i=1,nlocs
     phase(i)=unwrapped(loc(1,i)+len,loc(2,i))
     height(i)=dem(loc(1,i),loc(2,i))
!     print *,i,height(i),phase(i)
  end do

!c regression coeffs
  call linfit(height,phase,nlocs,poly)
!  print *,'regression polynomial ',poly
  open(21,file='regressionplot')
  do i=1,nlocs
!     ph=unwrapped(loc(1,i)+len,loc(2,i))
!     ht=dem(loc(1,i),loc(2,i))
      corr=-height(i)*poly(2)-poly(1)
      write(21,*)height(i),phase(i),corr
  end do
  close(21)

!c predict phase from height
!  do i=1,nlocs
!     print *,'regress predicts ',i,loc(:,i),phase(i),height(i),height(i)*poly(2)+poly(1)
!  end do

!c and apply it to the file
  do i=1,lines
     do j=1,len
        unwrapped(j+len,i)=unwrapped(j+len,i)-dem(j,i)*poly(2)-poly(1)
        if(iargc().ge.7)then
           phasecorr=-dem(j,i)*poly(2)-poly(1)
           igram(j,i)=igram(j,i)*cmplx(cos(phasecorr),sin(phasecorr))
        end if
     end do
  end do

!c  for tests output the correction layer
  do i=1,lines
     do j=1,len
        test(j,i)=unwrapped(j,i)
        test(j+len,i)=-dem(j,i)*poly(2)-poly(1)
     end do
  end do
  open(21,file='correction',access='direct',recl=len*8*lines)
  write(21,rec=1)test
  close(21)

!c save regressed files
  open(21,file=outfile,access='direct',recl=len*8*lines)
  write(21,rec=1)unwrapped
  close(21)
  if(iargc().ge.7)then
     open(21,file=trim(intfile)//'.reg',access='direct',recl=len*8*lines)
     write(21,rec=1)igram
     close(21)
  end if
  end


       subroutine linfit(xin,yin,ndata,poly)

! Polynomial to be fitted:
! Y = a(0) + a(1).X + a(2).X^2 + ... + a(m).X^m

         USE lsq
         IMPLICIT NONE
         
         REAL*8    :: x(10000),y(10000),xrow(0:20), wt = 1.0, beta(0:20), &
                       var, covmat(231), sterr(0:20), totalSS, center
         real*4  poly(3)
         REAL*4    :: xin(10000), yin(10000)
         INTEGER   :: i, ier, iostatus, j, m, n, ndata
         LOGICAL   :: fit_const = .TRUE., lindep(0:20), xfirst

      do i=1,ndata
         y(i)=yin(i)
         x(i)=xin(i)
      end do

      n=ndata
      m=1

! Least-squares calculations

      CALL startup(m, fit_const)
      DO i = 1, n
         xrow(0) = 1.0
         DO j = 1, m
            xrow(j) = x(i) * xrow(j-1)
         END DO
         CALL includ(wt, xrow, y(i))
      END DO

      CALL sing(lindep, ier)
      IF (ier /= 0) THEN
         DO i = 0, m
            IF (lindep(i)) WRITE(*, '(a, i3)') ' Singularity detected for power: ', i
         END DO
      END IF

! Calculate progressive residual sums of squares
      CALL ss()
      var = rss(m+1) / (n - m - 1)

! Calculate least-squares regn. coeffs.
      CALL regcf(beta, m+1, ier)

! Calculate covariance matrix, and hence std. errors of coeffs.
      CALL cov(m+1, var, covmat, 231, sterr, ier)
      poly(1)=beta(0)
      poly(2)=beta(1)
      poly(3)=beta(2)

!!$      WRITE(*, *) 'Least-squares coefficients & std. errors'
!!$      WRITE(*, *) 'Power  Coefficient          Std.error      Resid.sum of sq.'
!!$      DO i = 0, m
!!$         WRITE(*, '(i4, g20.12, "   ", g14.6, "   ", g14.6)')  &
!!$              i, beta(i), sterr(i), rss(i+1)
!!$      END DO
!!$      
!!$      WRITE(*, *)
!!$      WRITE(*, '(a, g20.12)') ' Residual standard deviation = ', SQRT(var)
!!$      totalSS = rss(1)
!!$      WRITE(*, '(a, g20.12)') ' R^2 = ', (totalSS - rss(m+1))/totalSS
      return

    end subroutine linfit