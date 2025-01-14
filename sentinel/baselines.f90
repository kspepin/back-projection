!!!!!
!
!  estimate the spatial baselines for a sentinel pair
!
!
!!!!!

program estimatebaseline
  use sql_mod

  implicit none

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
  !! DECLARE LOCAL VARIABLES
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
  character*300 str,demfile,demrscfile
  character*300 orbtimingfile,orbtimingfile1,orbtimingfile2

  integer*4 demwidth,demlength,idemwidth,idemlength,width,length
  integer*4 numstatevec,nlines

  real*8 deltalat,deltalon,firstlat,firstlon
  real*8 timeorbit(100),xx(3,100),vv(3,100),aa(3,100),x(3),v(3),a(3)
  real*8 timefirst,timeend
  real*8 orbitxyz1(3),orbitxyz2(3),u(3),bperp,u1(3),u2(3),uperp(3)
  real*8 tline, theta, vdotuperp

!!!! Satellite positions
  real*8 :: llh(3),xyz(3)
  real*8 :: satx(3), satv(3),sata(3)
  real*8 :: base3d(3)
  integer :: pixel,line,ith,i

  integer :: i_type

  ! declare some constants
  integer LLH_2_XYZ
  real*8 pi,rad2deg,deg2rad,sol 
  real*4 BAD_VALUE
  parameter(BAD_VALUE = -999999.0)
  parameter(LLH_2_XYZ=1)

  !c  types needed

  type :: ellipsoid 
     real*8 r_a           ! semi-major axis
     real*8 r_e2          ! eccentricity of earth ellisoid
  end type ellipsoid
  type(ellipsoid) :: elp

  elp%r_a=6378137.0
  elp%r_e2=0.0066943799901499996

  pi = 4.d0*atan2(1.d0,1.d0)
  sol = 299792458.d0
  rad2deg = 180.d0/pi
  deg2rad = pi/180.d0

  if(iargc().lt.2)then
     print *,'usage: baselines orbtimingfile1 orbtimingfile2'
     stop
  end if

  call getarg(1,orbtimingfile1)
  call getarg(2,orbtimingfile2)

  !c  get dem and rsc file names
  open(21,file='params')
  read(21,'(a)')demfile
  read(21,'(a)')demrscfile
  close(21)
  !print *,'dem file: ',demfile
  !print *,'demrscfile: ',demrscfile

  !c  read in the dem and its resource parameters
  open(21,file=demrscfile)
  read(21,'(a)')str
  read(str(15:60),*)demwidth
  read(21,'(a)')str
  read(str(15:60),*)demlength
  read(21,'(a)')str
  read(str(15:60),*)firstlon
  read(21,'(a)')str
  read(str(15:60),*)firstlat
  read(21,'(a)')str
  read(str(15:60),*)deltalon
  read(21,'(a)')str
  read(str(15:60),*)deltalat
  close(21)

!!$  print *,'DEM parameters:'
!!$  print *,demwidth,demlength,firstlon,firstlat,deltalon,deltalat

  !c read in the orbit state vectors for file 1

  orbtimingfile=trim(orbtimingfile1)
  open(21,file=orbtimingfile)
  read(21,*)timefirst
  read(21,*)timeend
  read(21,*)nlines
  read(21,*)numstatevec
  !print *,'Number of state vectors: ',numstatevec

  !c  read in state vectors
  do i=1,numstatevec
     read(21,*)timeorbit(i),x,v,a
     xx(:,i)=x
     vv(:,i)=v
     aa(:,i)=a
     !print *,timeorbit(i)
  end do
  close(21)

  llh(1) = (firstlat+demlength*deltalat/2.) * deg2rad
  llh(2) = (firstlon+demwidth*deltalon/2.) * deg2rad
  llh(3) = 1000.
  !                 print *,line,pixel,llh
  i_type = LLH_2_XYZ
  call latlon(elp,xyz,llh,i_type)


  ! initial guess at location from center of orbtiming file
  tline = timeorbit((numstatevec/2)+1)
  satx = xx(:,((numstatevec/2)+1))
  satv = vv(:,((numstatevec/2)+1))
!!$  print '(7f12.3)',tline,satx,satv

  call orbitlocation(xyz,timeorbit,xx,vv,numstatevec, &
       tline,satx,satv,orbitxyz1)

  ! same for second file
  orbtimingfile=trim(orbtimingfile2)
  open(21,file=orbtimingfile)
  read(21,*)timefirst
  read(21,*)timeend
  read(21,*)nlines
  read(21,*)numstatevec
  !print *,'Number of state vectors: ',numstatevec

  !c  read in state vectors
  do i=1,numstatevec
     read(21,*)timeorbit(i),x,v,a
     xx(:,i)=x
     vv(:,i)=v
     aa(:,i)=a
     !print *,timeorbit(i)
  end do
  close(21)

  tline = timeorbit((numstatevec/2)+1)
  satx = xx(:,((numstatevec/2)+1))
  satv = vv(:,((numstatevec/2)+1))
!!$  print '(7f12.3)',tline,satx,satv

  call orbitlocation(xyz,timeorbit,xx,vv,numstatevec, &
       tline,satx,satv,orbitxyz2)

!!$  print *,'xyz        ',xyz
!!$  print *,'xyz orbit1 ',orbitxyz1
!!$  print *,'xyz orbit2 ',orbitxyz2
  base3d=orbitxyz2-orbitxyz1
!!$  print *,'3d baseline',base3d

!!$  ! compute bperp component
!!$  u = xyz - (orbitxyz1+orbitxyz2)/2.
!!$  u = u / sqrt(dot_product(u,u))
!!$
!!$  bperp =base3d - dot_product(base3d,u)*u
!!$  print *,sqrt(dot_product(bperp,bperp))

  u1=(orbitxyz1-xyz)/sqrt(dot_product(orbitxyz1-xyz,orbitxyz1-xyz))
  u2=(orbitxyz2-xyz)/sqrt(dot_product(orbitxyz2-xyz,orbitxyz2-xyz))
  uperp(1)=u1(2)*u2(3)-u1(3)*u2(2)
  uperp(2)=u1(3)*u2(1)-u1(1)*u2(3)
  uperp(3)=u1(1)*u2(2)-u1(2)*u2(1)
  theta=asin(sqrt(dot_product(uperp,uperp)))
  vdotuperp=dot_product(satv,uperp)
  if(vdotuperp.gt.0)then
     bperp=sqrt(dot_product(orbitxyz1-xyz,orbitxyz1-xyz))*theta
  else
     bperp=-sqrt(dot_product(orbitxyz1-xyz,orbitxyz1-xyz))*theta
  end if

  print *,'Perpendicular baseline: ',bperp
  print *,'Baseline magnitude: ',sqrt(dot_product(base3d,base3d))
  print *,'Parallel baseline magnitude: ',sqrt(dot_product(base3d,base3d)-bperp**2)
  print *,'3D baseline: ',base3d

end program estimatebaseline

subroutine orbitlocation(xyz,timeorbit,xx,vv,numstatevec,tline0,satx0,satv0,orbitxyz)

  implicit none

  !c  inputs
  real*8 xyz(3)                          !  point on ground
  real*8 timeorbit(*), xx(3,*), vv(3,*)  !  orbit state vectors
  real*8 tline0, satx0(3),satv0(3)       !  initial search point 
  !c  outputs
  real*8 tline,range                     !  solution for orbit time, range
  !c  internal variables
  real*8 satx(3),satv(3),tprev,dr(3),dopfact,fn,c1,c2,fnprime,BAD_VALUE
  real*8 orbitxyz(3)
  real*8 rngpix
  integer k, stat, intp_orbit, numstatevec

  BAD_VALUE=-999999.99999999d0

  !c  starting state
  tline = tline0
  satx = satx0
  satv = satv0

!!$        print *,'start satx v ',satx,satv

  do k=1,51!51
     tprev = tline  

     dr = xyz - satx
     rngpix = dsqrt(dot_product(dr,dr)) !norm2(dr)    

     dopfact = dot_product(dr,satv)
!!$            fdop = 0.5d0 * wvl * evalPoly1d_f(fdvsrng,rngpix)
!!$            fdopder = 0.5d0 * wvl * evalPoly1d_f(fddotvsrng,rngpix)

     fn = dopfact !- fdop * rngpix

     c1 = -dot_product(satv,satv) !(0.0d0 * dot(sata,dr) - dot(satv,satv))
     c2 = 0. !(fdop/rngpix + fdopder)

     fnprime = c1 + c2*dopfact

     !!            if (abs(fn) .le. 1.0d-5) then
     !!                conv = conv + 1
     !!                exit
     !!            endif

     tline = tline - fn / fnprime

     !!            print *, c1, c2, rngpix

     stat = intp_orbit(timeorbit,xx,vv,numstatevec,tline,satx,satv)

     if (stat.ne.0) then
        tline = BAD_VALUE
        rngpix = BAD_VALUE
        exit
     endif

     !            stat = computeAcceleration_f(orbit,tline,sata)
     !            if (stat.ne.0) then
     !                tline = BAD_VALUE
     !                rngpix = BAD_VALUE
     !                exit
     !            endif

!!!Check for convergence
     if (abs(tline - tprev).lt.5.0d-9) then
        !conv = conv + 1
        exit
     endif
  enddo  ! end iteration loop
  !numiter(pixel)=k

  dr = xyz - satx
  rngpix = dsqrt(dot_product(dr,dr)) !norm2(dr)
  range=rngpix
  !print *,'end   satx v ',satx,satv,rngpix,tline
  orbitxyz=satx

  return
end subroutine orbitlocation
