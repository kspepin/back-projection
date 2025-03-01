!!!!!!!!!!!!!!
!
!
!  azimuth compression subroutine for use in back projection processor
!
!
!!!!!!!!!!!!!!

subroutine azimuth_compress(burstdata,satloc,rawdatalines,samplesPerBurst,demwidth,demlength,fdout,fddem, &
       deltalat,deltalon,firstlat,firstlon, &
       latlons,timeorbit,xx,vv,numstatevec,rngstart,rngend,tstart,tend, &
       tmid,xyz_mid,vel_mid,t,dtaz,dmrg,wvl,aperture,iaperture,angc0,angc1,prf)

  implicit none

! parameters
  integer stat,intp_orbit
  integer*4 fddem, fdout, ioseek, ioread, iowrit
  integer*4 samplesPerBurst
  integer*4 demwidth,demlength
  integer*4 numstatevec,iaperture
  real*8 deltalat,deltalon,firstlat,firstlon
  real*8 timeorbit(1000),xx(3,1000),vv(3,1000)
  real*8 satloc(3,100000),satvel(3,100000)
  real*8 :: lat
  real*8, dimension(:),allocatable :: lon
  real*8 :: azoff
  integer*2, allocatable :: demin(:)

! internal parameters
!!!!Image limits
  real*8 tstart, tend, tline
  real*8 rngstart, rngend, rngpix, latlons(4)

!!!! Satellite positions
  real*8, dimension(3) :: xyz_mid, vel_mid, acc_mid
  real*8 :: tmid, rngmid, temp, t(100000)

  real*8 :: llh(3),xyz(3)
  real*8 :: satx(3), satv(3),sata(3)
  integer :: pixel,line,ith,i

  integer :: i_type, azline, intr,aperture 
  real*8 :: dtaz, dmrg, range,r,fracr,phase
  complex*8 :: val
  complex*16 :: cacc
  complex*8 :: pixelint

  ! array to hold burst
  complex*8 :: burstdata(rawdatalines,samplesPerBurst)
  complex*8, allocatable :: outdata(:), baddata(:)
  real*8 :: wvl

  integer*4  rawdatalines,nbytes

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

  allocate(demin(demwidth), outdata(demwidth), lon(demwidth))

  print *,pi,sol,rad2deg,deg2rad
  print *,'burstdata,satloc'
  print *,burstdata(1,1),burstdata(rawdatalines,samplesPerBurst)
  print *,satloc(:,1),satloc(:,rawdatalines)

  ! begin loop over lines in dem
  print *,demwidth,firstlon,deltalon
  do i=1,demwidth
     lon(i)=firstlon+(i-1)*deltalon
  end do

  print *,lon(1),lon(demwidth),demlength

  do line = 1, demlength
     if(mod(line,100).eq.1)print *,'dem line ',line
     !!Initialize
     azoff = BAD_VALUE
     outdata=cmplx(0.,0.)
!     print *,'line initialized ',line,BAD_VALUE,outdata(1),azoff

     lat=firstlat+(line-1)*deltalat
     ! if outside range dont bother with computations
!     print *,line,lat,latlons(1),latlons(2)
     if(lat.ge.latlons(1))then
        if(lat.le.latlons(2))then
           
           !!Read in this line from DEM
           nbytes=ioseek(fddem,int8((line-1)*demwidth*2))
           nbytes=ioread(fddem,demin,int8(demwidth*2))
!           print *,'bytes read ',fddem,nbytes,demin(1),demin(demwidth)
           !              read(22,rec=line)demin
           if (mod(line,1000).eq.1) then
              print *, 'Processing line: ', line
           endif
           
           !$OMP PARALLEL DO private(i_type)&
           !$OMP private(xyz,llh,rngpix,tline,satx,satv,cacc)&
           !$OMP private(azoff,azline,range,r,intr,fracr,val,phase)&
           !$OMP shared(lat,lon,demin,burstdata) &
           !$OMP shared(demwidth,outdata,samplesPerBurst) &
           !$OMP shared (timeorbit,xx,vv,numstatevec) &
           !$OMP shared(elp,rngstart,tstart,tend,rngend) &
           !$OMP shared(tmid,xyz_mid,vel_mid,t) &
           !$OMP shared(dtaz,dmrg,deg2rad) &
           !$OMP shared(wvl,pi,rawdatalines,satloc,aperture,iaperture) 
           do pixel = 1,demwidth 

              llh(1) = lat * deg2rad
              llh(2) = lon(pixel) * deg2rad
              llh(3) = demin(pixel)
!              print *,line,pixel,llh
              i_type = LLH_2_XYZ
              call latlon(elp,xyz,llh,i_type)
              tline = tmid
              satx = xyz_mid
              satv = vel_mid
!              print *,xyz,tline,satx
!                 sata = acc_mid
                 !! get the zero doppler location of the satellite
              call orbitrangetime(xyz,timeorbit,xx,vv,numstatevec, &
                   tmid,satx,satv,tline,rngpix)
!              print *,'tline rngpix ',tline,rngpix,dtaz,dmrg
!              print *,'pixelint args'
!              print *,aperture,iaperture,rawdatalines,xyz,rngstart,rngend,dmrg,pi,wvl
              if(tline.ge.tstart.and.tline.le.tend)then
                 azoff = ((tline - tstart)/dtaz) !- 1.0d0*(line-1)
                 phase=4.d0*pi/wvl*rngpix
!                 print *,burstdata(1,1),burstdata(rawdatalines,samplesPerBurst)
!                 print *,azoff,satloc(:,nint(azoff))
                 outdata(pixel)=pixelint(burstdata,satloc,azoff,aperture,iaperture,rawdatalines,xyz, &
                      rngstart,rngend,dmrg,pi,wvl)
                 
              end if
           enddo   ! end pixel loop
           !$OMP END PARALLEL DO

           !!Write line to output file
           nbytes=ioseek(fdout,int8((line-1)*demwidth*8))
           nbytes=iowrit(fdout,outdata,int8(demwidth*8))

        end if
     end if ! end if that checks if inside latitude line bounds
     
  end do ! line loop ends here

!!$  close(31)
  deallocate(lon,demin)
  return
end subroutine azimuth_compress

