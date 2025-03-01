program geometry

  implicit none
  real*8, allocatable :: timeorbit(:),xx(:,:),vv(:,:)
  real*8 timedelta,x(3),v(3)
  real*8 startime,endtime,startr,endr,latlons(4)
  real*8 xyzsatstart(3),velsatstart(3),xyzsatend(3),velsatend(3)
  real*8 xyzsatmid(3),velsatmid(3),xyz(3),xyz0(3),xyz1(3)
  real*8 llhsat(3),llh(3),xyzsat(3),velsat(3),time
  real*8 vhat(3),that(3),nhat(3),chat(3)
  real*8 alpha,beta,gamm,delta(3),aa,bb,hgts(2),zsch,costheta,sintheta,dopfact
  real*8 pi,sol,r2d,d2r
  real*8 r_lati,r_loni,r_latf,r_lonf,r_geohdg
  real*8 rcurv,rng,r_e2,r_a,vmag,height
  real*8 min_lat,max_lat,min_lon,max_lon
  real*8 firstlon, firstlat, deltalon, deltalat
  real*8 r,cosalpha,cosalphaprime,deltar,xspace,yspace
  real*8 r_p, r_local, rnum, rden, rclose
  real*8 uxyz(3),uenu(3),ue(3),un(3),uu(3),rlook(3),llhtest(3),uproj(3)
  integer demwidth, demlength
  integer i_type,ind,iter,line,stat,numstatevec,i,j,ret,iclose,jclose,nvect,ilocation
  character*300 posfile, str

  !  function types
  real*8 norm2
  integer intp_orbit

  integer XYZ_2_LLH
  integer unit

!c  types needed
  type :: ellipsoid 
     real*8 r_a           ! semi-major axis
     real*8 r_e2          ! eccentricity of earth ellisoid
  end type ellipsoid
  type(ellipsoid) :: elp

  elp%r_a=6378137.0
  elp%r_e2=0.0066943799901499996
  r_a=6378137.0
  r_e2=0.0066943799901499996

  r_p = sqrt(r_a**2-r_a**2*r_e2)
  pi = 4.d0*atan2(1.d0,1.d0)
  sol = 299792458.d0
  r2d = 180.d0/pi
  d2r = pi/180.d0

  XYZ_2_LLH=2

  if(iargc().lt.1)then
     print *,'Usage: geometry <precise_orbtiming=precise_orbtiming>'
     posfile='precise_orbtiming'
  end if

  if(iargc().ge.1)call getarg(1,posfile)

! read in the orbtiming file - usually state vectors at 10 sec centers
  open(22,file=posfile)
  read(22,*)nvect
  read(22,*)nvect
  read(22,*)nvect
  read(22,*)nvect ! only 4th one counts
  allocate (timeorbit(nvect),xx(3,nvect),vv(3,nvect))
  do i=1,nvect
     read(22,*)timeorbit(i),xx(:,i),vv(:,i)
!         print *,timeorbit(i),orbitfile
  end do
  close(22)
  timedelta=timeorbit(2)-timeorbit(1)

! estimate dem spacing at center of DEM
  open(21,file='elevation.dem.rsc')
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

!  print *,'DEM parameters:'
!  print *,demwidth,demlength,firstlon,firstlat,deltalon,deltalat
  
  llh(1)=(firstlat+(demlength/2)*deltalat)*pi/180.
  llh(2)=(firstlon+(demwidth/2)*deltalon)*pi/180.
  llh(3)=0.
  call latlon(elp, xyz0, llh, 1)  ! location of dem center, zero height
  !  get local earth radius
!  print *,r_a, r_p, llh(1), cos(llh(1)), sin(llh(1))
  rnum=(r_a**2*cos(llh(1)))**2+(r_p**2*sin(llh(1)))**2
  rden=(r_a*cos(llh(1)))**2+(r_p*sin(llh(1)))**2
  r_local=sqrt(rnum/rden)
!  print *,'r local ',r_local

! point of closest approach, first get closest state vector
  jclose=0
  rclose=1.e20
  do i=1,nvect
     xyzsat=xx(:,i)
     if(rclose.gt.sqrt(dot_product(xyzsat-xyz0,xyzsat-xyz0)))then
        rclose=sqrt(dot_product(xyzsat-xyz0,xyzsat-xyz0))
        jclose=i
        xyzsatmid=xyzsat !  xyzsatmid now contains point of closest approach
     end if
  end do
!  print *,'state vector at closest approach ',jclose,rclose
  if (jclose.lt.2.or.jclose.gt.nvect-1)then
     print *,'precise orbtimimg range does not contain proper minimum'
     call exit
  end if

  if(sqrt(dot_product(xx(:,jclose-1)-xyz0,xx(:,jclose-1)-xyz0)).le.sqrt(dot_product(xx(:,jclose+1)-xyz0,xx(:,jclose+1)-xyz0)))then
     jclose=jclose-1
  end if
  if (jclose.lt.2)then
     print *,'precise orbtimimg range does not contain proper minimum'
     call exit
  end if
!  print *,'state vector at closest approach ',jclose,rclose

  ! now find closest millisecond in range
  xyzsatstart=xx(:,jclose-1)
  xyzsatend=xx(:,jclose+1)
  iclose=0
  rclose=1.e20
  do i=0,2*nint(timedelta/0.001)
     time=timeorbit(jclose-1)+i*0.001
     ilocation=(time-timeorbit(1))/timedelta
     !print *,time,ilocation,timeorbit(1),timedelta
     call orbithermite(xx(1,ilocation-1),vv(1,ilocation-1),timeorbit(ilocation-1),time,x,v)
     xyzsat=x
     if(rclose.gt.sqrt(dot_product(xyzsat-xyz0,xyzsat-xyz0)))then
        rclose=sqrt(dot_product(xyzsat-xyz0,xyzsat-xyz0))
        iclose=i
        xyzsatmid=xyzsat !  xyzsatmid now contains point of closest approach
     end if
     
  end do
  print *,'Closest approach: ',iclose,rclose,' of lines=',i

!  sanity check on llh values of satellite, dem
  call latlon(elp, xyzsatmid,llhtest,2)
  print *,'llh satellite location        ',llhtest(1)*180/3.14159,llhtest(2)*180/3.14159,llhtest(3)
  call latlon(elp, xyz0,llhtest,2)
  print *,'llh dem midpoint, zero height ',llhtest(1)*180/3.14159,llhtest(2)*180/3.14159,llhtest(3)

  print *,'xyz coords of satellite closest approach ',xyzsatmid
  print *,'xyz coords of dem midpoint, zero height  ',xyz0
  rlook=xyzsatmid-xyz0
  print *,'Vector surface to satellite, xyz coords  ',rlook
  uxyz=rlook
  ret=unit(uxyz)
  print *,'unit look vector to satellite            ',uxyz

  llh(1)=(firstlat+(demlength/2)*deltalat)*pi/180.
  llh(2)=(firstlon+(demwidth/2+1)*deltalon)*pi/180.
  llh(3)=0.
  call latlon(elp, xyz1, llh, 1)
!  print *,'vector to east ',xyz1-xyz0
  ue=xyz1-xyz0
  ret=unit(ue)
  print *,'unit vector east, xyz coords  ',ue

  xspace=r_local*acos(dot_product(xyz0,xyz1)/sqrt(dot_product(xyz0,xyz0)*dot_product(xyz1,xyz1)))
!  print *,xyz1
!  print *,'xspace ',r_a*acos(dot_product(xyz0,xyz1)/sqrt(dot_product(xyz0,xyz0)*dot_product(xyz1,xyz1)))

  llh(1)=(firstlat+(demlength/2-1)*deltalat)*pi/180.
  llh(2)=(firstlon+(demwidth/2)*deltalon)*pi/180.
  llh(3)=0.
  call latlon(elp, xyz1, llh, 1)
!  print *,'vector to north ',xyz1-xyz0
  un=xyz1-xyz0
  ret=unit(un)
  print *,'unit vector north, xyz coords ',un
  yspace=r_local*acos(dot_product(xyz0,xyz1)/sqrt(dot_product(xyz0,xyz0)*dot_product(xyz1,xyz1)))

  llh(1)=(firstlat+(demlength/2)*deltalat)*pi/180.
  llh(2)=(firstlon+(demwidth/2)*deltalon)*pi/180.
  llh(3)=10.
  call latlon(elp, xyz1, llh, 1)  ! up direction
  uu=xyz1-xyz0
  ret=unit(uu)
  print *,'unit vector up, xyz coords    ',uu

!  print *,xyz1
!  print *,'yspace ',r_a*acos(dot_product(xyz0,xyz1)/sqrt(dot_product(xyz0,xyz0)*dot_product(xyz1,xyz1)))

  r=sqrt(dot_product(xyzsatmid-xyz0,xyzsatmid-xyz0))
  print *,'Unit look vector, ground to satellite: ',(xyzsatmid-xyz0)/r
  uxyz=xyzsatmid-xyz0
  ret=unit(uxyz)
  print *,'unit look vector xyz coords            ',uxyz

  uenu(1)=dot_product(uxyz,ue)
  uenu(2)=dot_product(uxyz,un)
  uenu(3)=dot_product(uxyz,uu)
  print *,'unit look vector enu coords:           ',uenu
  ! project unit vector to surface and estimate heading
  uproj=uenu;
  uproj(3)=0;
  ret=unit(uproj);
  print *,'Uenu projected onto surface            ',uproj

  cosalpha=(dot_product(xyzsatmid,xyzsatmid)+r_local**2-r**2)/2/r_local/sqrt(dot_product(xyzsatmid,xyzsatmid))
  cosalphaprime=(dot_product(xyzsatmid,xyzsatmid)+(r_local+1)**2-r**2)/2/(r_local+1)/sqrt(dot_product(xyzsatmid,xyzsatmid))
  deltar=r_local*(acos(cosalphaprime)-acos(cosalpha))
!  print *,'r cosalpha cosalphaprime deltar ',r,cosalpha,cosalphaprime,deltar

  i_type = XYZ_2_LLH
  call latlon(elp, xyzsatstart, llhsat, i_type)
  r_lati=llhsat(1)
  r_loni=llhsat(2)
  height = llhsat(3)
  call latlon(elp, xyzsatend, llhsat, i_type)
  r_latf=llhsat(1)
  r_lonf=llhsat(2)
  height = (height+llhsat(3))/2.d0
  call geo_hdg(r_a,r_e2,r_lati,r_loni,r_latf,r_lonf,r_geohdg)     
!  print *,'Estimated, true headings ',atan2(uproj(2),-uproj(1))*180/3.14159,r_geohdg*180/3.14159
  print *,'Heading, degrees, rad ',r_geohdg*180/3.14159,r_geohdg

!  print *,'heading= ',r_geohdg,180/pi*r_geohdg
  print *,'Deltar, xspacing, yspacing, ',deltar,xspace,yspace
  end

!c****************************************************************

	subroutine geo_hdg(r_a,r_e2,r_lati,r_loni,r_latf,r_lonf,r_geohdg)

!c****************************************************************
!c**
!c**	FILE NAME: geo_hdg.f
!c**
!c**     DATE WRITTEN:12/02/93 
!c**
!c**     PROGRAMMER:Scott Hensley
!c**
!c** 	FUNCTIONAL DESCRIPTION: This routine computes the heading along a geodesic
!c**     for either an ellipitical or spherical earth given the initial latitude
!c**     and longitude and the final latitude and longitude. 
!c**
!c**     ROUTINES CALLED:none
!c**  
!c**     NOTES: These results are based on the memo
!c**
!c**        "Summary of Mocomp Reference Line Determination Study" , IOM 3346-93-163
!c**
!c**      and the paper
!c**
!c**        "A Rigourous Non-iterative Procedure for Rapid Inverse Solution of Very
!c**         Long Geodesics" by E. M. Sadano, Bulletine Geodesique 1958
!c**
!c**     ALL ANGLES ARE ASSUMED TO BE IN RADIANS!   
!c**
!c**     UPDATE LOG:
!c**
!c*****************************************************************

       	implicit none

!c	INPUT VARIABLES:
        real*8 r_a                    !semi-major axis
	real*8 r_e2                   !square of eccentricity
        real*8 r_lati                 !starting latitude
        real*8 r_loni                 !starting longitude
        real*8 r_latf                 !ending latitude
        real*8 r_lonf                 !ending longitude  
     
!c   	OUTPUT VARIABLES:
        real*8 r_geohdg

!c	LOCAL VARIABLES:
        real*8 pi,r_t1,r_t2,r_e,r_ome2,r_sqrtome2,r_b0,r_f,r_ep,r_n
        real*8 r_k1,r_k2,r_k3,r_k4,r_k5,r_l,r_ac,r_bc,r_phi,r_phi0
        real*8 r_tanbetai,r_cosbetai,r_sinbetai,r_cosphi,r_sinphi
        real*8 r_tanbetaf,r_cosbetaf,r_sinbetaf,r_lambda,r_coslam,r_sinlam
        real*8 r_ca,r_cb,r_cc,r_cd,r_ce,r_cf,r_cg,r_ch,r_ci,r_cj,r_x,r_q
        real*8 r_sinlati,r_coslati,r_tanlatf,r_tanlati,r_coslon,r_sinlon
        real*8 r_sin2phi,r_cosph0,r_sinph0,r_cosbeta0,r_cos2sig,r_cos4sig
        real*8 r_cotalpha12,r_cotalpha21,r_lsign 
        logical l_first

!c	DATA STATEMENTS:
        data pi /3.141592653589793d0/
        data l_first /.true./ 

!c       SAVE STATEMENTS: (needed on Freebie only)
        save l_first,r_e,r_ome2,r_sqrtome2,r_b0,r_f,r_ep
        save r_n,r_k1,r_k2,r_k3,r_k4,r_k5
 
!c	FUNCTION STATEMENTS: none

!c  	PROCESSING STEPS:

        if(r_e2 .eq. 0)then   !use the simplier spherical formula

	   r_sinlati = sin(r_lati)
	   r_coslati = cos(r_lati)
           r_tanlatf = tan(r_latf)

           r_t1 =  r_lonf - r_loni
	   if(abs(r_t1) .gt. pi)then
	      r_t1 = -(2.d0*pi - abs(r_t1))*sign(1.d0,r_t1)
           endif 
 
           r_sinlon = sin(r_t1)
           r_coslon = cos(r_t1)
           r_t2 = r_coslati*r_tanlatf - r_sinlati*r_coslon

           r_geohdg = atan2(r_sinlon,r_t2)

        else   ! use the full ellipsoid formulation

          if(l_first)then 
             l_first = .false.
	     r_e = sqrt(r_e2)
	     r_ome2 = 1.d0 - r_e2
	     r_sqrtome2 = sqrt(r_ome2)
             r_b0 = r_a*r_sqrtome2
	     r_f = 1.d0 - r_sqrtome2
	     r_ep = r_e*r_f/(r_e2-r_f)
	     r_n = r_f/r_e2
	     r_k1 = (16.d0*r_e2*r_n**2 + r_ep**2)/r_ep**2   
             r_k2 = (16.d0*r_e2*r_n**2)/(16.d0*r_e2*r_n**2 + r_ep**2)
             r_k3 = (16.d0*r_e2*r_n**2)/r_ep**2
             r_k4 = (16.d0*r_n - r_ep**2)/(16.d0*r_e2*r_n**2 + r_ep**2)
             r_k5 = 16.d0/(r_e2*(16.d0*r_e2*r_n**2 + r_ep**2))
          endif

          r_tanlati = tan(r_lati)
          r_tanlatf = tan(r_latf)
          r_l  =  abs(r_lonf-r_loni)
          r_lsign = r_lonf - r_loni
          if(abs(r_lsign) .gt. pi)then
	     r_lsign = -(2.d0*pi - r_l)*sign(1.d0,-r_lsign)
	  endif
          r_sinlon = sin(r_l)
          r_coslon = cos(r_l)
 
          r_tanbetai = r_sqrtome2*r_tanlati
          r_tanbetaf = r_sqrtome2*r_tanlatf

          r_cosbetai = 1.d0/sqrt(1.d0 + r_tanbetai**2)
          r_cosbetaf = 1.d0/sqrt(1.d0 + r_tanbetaf**2)
          r_sinbetai = r_tanbetai*r_cosbetai        
          r_sinbetaf = r_tanbetaf*r_cosbetaf

          r_ac = r_sinbetai*r_sinbetaf        
          r_bc = r_cosbetai*r_cosbetaf        
 
          r_cosphi = r_ac + r_bc*r_coslon
          r_sinphi = sign(1.d0,r_sinlon)*sqrt(1.d0 - min(r_cosphi**2,1.d0))
          r_phi = abs(atan2(r_sinphi,r_cosphi))
          
          if(r_a*abs(r_phi) .gt. 1.0d-6)then

	     r_ca = (r_bc*r_sinlon)/r_sinphi
	     r_cb = r_ca**2
	     r_cc = (r_cosphi*(1.d0 - r_cb))/r_k1
	     r_cd = (-2.d0*r_ac)/r_k1
	     r_ce = -r_ac*r_k2
	     r_cf = r_k3*r_cc
	     r_cg = r_phi**2/r_sinphi
	     
	     r_x = ((r_phi*(r_k4 + r_cb) + r_sinphi*(r_cc + r_cd) + r_cg*(r_cf + r_ce))*r_ca)/r_k5
	     
	     r_lambda = r_l + r_x
	     
	     r_sinlam = sin(r_lambda)
	     r_coslam = cos(r_lambda)
	     
	     r_cosph0 = r_ac + r_bc*r_coslam
	     r_sinph0 = sign(1.d0,r_sinlam)*sqrt(1.d0 - r_cosph0**2)
	     
	     r_phi0 = abs(atan2(r_sinph0,r_cosph0))
	     
	     r_sin2phi = 2.d0*r_sinph0*r_cosph0
	     
	     r_cosbeta0 = (r_bc*r_sinlam)/r_sinph0
	     r_q = 1.d0 - r_cosbeta0**2
	     r_cos2sig = (2.d0*r_ac - r_q*r_cosph0)/r_q
	     r_cos4sig = 2.d0*(r_cos2sig**2 - .5d0)
	     
	     r_ch = r_b0*(1.d0 + (r_q*r_ep**2)/4.d0 - (3.d0*(r_q**2)*r_ep**4)/64.d0)
	     r_ci = r_b0*((r_q*r_ep**2)/4.d0 - ((r_q**2)*r_ep**4)/16.d0)
	     r_cj = (r_q**2*r_b0*r_ep**4)/128.d0
	     
	     r_t2 = (r_tanbetaf*r_cosbetai - r_coslam*r_sinbetai)
	     r_sinlon = r_sinlam*sign(1.d0,r_lsign)
	     
	     r_cotalpha12 = (r_tanbetaf*r_cosbetai - r_coslam*r_sinbetai)/r_sinlam
	     r_cotalpha21 = (r_sinbetaf*r_coslam - r_cosbetaf*r_tanbetai)/r_sinlam
	     
	     r_geohdg = atan2(r_sinlon,r_t2)
	     
          else
	     
	     r_geohdg = 0.0d0
!c             type*, 'Out to lunch...'
	     
          endif
 
	endif
       
        end  

  integer function unit(u)
    real*8 u(3)
    u=u/sqrt(u(1)**2+u(2)**2+u(3)**2)
  end function unit

