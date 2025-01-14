c****************************************************************

      Program resamp_only

c****************************************************************
c**
c**  from resamp_roi but does the resample only, no interferogram formation
c**    
c**   FILE NAME: resamp_roi.F
c**     
c**   DATE WRITTEN: Long, long ago. (March 16, 1992)
c**     
c**   PROGRAMMER: Charles Werner, Paul Rosen and Scott Hensley
c**     
c**   FUNCTIONAL DESCRIPTION: Interferes two SLC images 
c**   range, azimuth interpolation with a quadratic or sinc interpolator 
c**   no circular buffer is used, rather a batch algorithm is implemented
c**   The calculation of the range and azimuth offsets is done for
c**   each of the data sets in the offset data file. As soon as the
c**   current line number exceeds the range line number for one of the
c**   data sets in the offset data file, the new lsq coefficients are
c**   to calculate the offsets for any particular range pixel. 
c**     
c**   ROUTINES CALLED:
c**     
c**   NOTES: 
c**     
c**   UPDATE LOG:
c**
c**   Date Changed        Reason Changed 
c**   ------------       ----------------
c**     20-apr-92    added removal/reinsertion of range phase slope to 
c**                  improve correlation
c**     11-may-92    added code so that the last input block of data is processed
c**                  even if partially full
c**     9-jun-92     modified maximum number of range pixels
c**     17-nov-92    added calculation of the range phase shift/pixel
c**     29-mar-93    write out multi-look images (intensity) of the two files 
c**     93-99        Stable with small enhancements changes
c**     Dec 99       Modified range interpolation to interpret (correctly)
c**                  the array indices to be those of image 2 coordinates.  
c**                  Previous code assumed image 1, and therefore used 
c**                  slightly wrong offsets for range resampling depending
c**                  on the gross offset between images.  Mods involve computing
c**                  the inverse mapping
c**     Aug 16, 04   This version uses MPI (Message Passing Interface)
c**                  to parallelize the resamp_roi sequential computations.
c**                  File Name is changed to resamp_roi.F in order to use
c**                  the Fortran compiler pre-processor to do conditional
c**                  compiling (#ifdef etc).  This code can be compiled for
c**                  either sequential or parallel uses. Compiler flag 
c**                  -DMPI_PARA is needed in order to pick up the MPI code.
c**
c*****************************************************************

      implicit none

c     INCLUDE FILES:

c     PARAMETER STATEMENTS:

      integer    NPP,MP
      parameter (NPP=10)

      real*8   PI
      integer  NP, NAZMAX, N_OVER, NBMAX, NLINESMAX
      parameter (PI=3.1415926535d0)
      parameter (NP=20000)	!maximum number of range pixels
      parameter (NLINESMAX=200000) ! maximum number of SLC lines
      parameter (NAZMAX=16)	        !number of azimuth looks
      parameter (N_OVER=2000)  !overlap between blocks
      parameter (NBMAX=200*NAZMAX+2*N_OVER) !number of lines in az interpol

      integer MINOFFSSAC, MINOFFSSDN, OFFDIMAC, OFFDIMDN
      parameter (MINOFFSSAC=100, MINOFFSSDN=500)
      parameter (OFFDIMAC=NP/MINOFFSSAC, OFFDIMDN=NLINESMAX/MINOFFSSDN)
      parameter (MP=OFFDIMAC*OFFDIMDN)

      integer FL_LGT
      parameter (FL_LGT=8192*8)

      integer MAXDECFACTOR      ! maximum lags in interpolation kernels
      parameter(MAXDECFACTOR=8192)                        
      
      integer MAXINTKERLGH      ! maximum interpolation kernel length
      parameter (MAXINTKERLGH=8)
      
      integer MAXINTLGH         ! maximum interpolation kernel array size
      parameter (MAXINTLGH=MAXINTKERLGH*MAXDECFACTOR)

c     INPUT VARIABLES:
	
c     OUTPUT VARIABLES:

c     LOCAL VARIABLES:

      logical ex
      character*120 f(5),a_cmdfile,a_offfile,a_temp
      character*120 as
      
      integer ierr, istats, l1, l2, lr, lc, line, iargc, iflatten
      integer ist, istoff, iaz, npl, npl2, nplo, nr, naz, nl, i_numpnts
      integer ibs, ibe, irec, i_a1, i_r1, jrec, jrecp
      integer i, j, k, ii, ix, nb
      integer int_az_off
      integer int_rd(0:NP-1)
      integer int_az(0:NP-1)
      integer i_na, ibfcnt,i_ma       

      real*4  fintp(0:FL_LGT-1),f_delay
      real am(0:NP-1,0:NAZMAX-1),amm(0:NP-1)
      real bm(0:NP-1,0:NAZMAX-1),bmm(0:NP-1)
      complex abmm(0:NP-1)
      
      real*8 fr_rd(0:NP-1),fr_az(0:NP-1)

      real*8 wvl, cpp, rphs, aa1, rphs1, r_ro, r_ao, rsq, asq, rmean
      real*8 amean, slr, azsum, azoff1, r_st, rd, azs
      real*8 r_rt,r_at, azmin
c      real*8 prf1, prf2

      complex cm(0:NP-1)
      complex dm(0:NP-1)
      complex em(0:NP-1)
      real*8 fd(0:NP-1)
      
      complex a(0:NP-1),b(0:NP-1,0:NBMAX-1),tmp(0:NP-1)
      complex cc(0:NP-1),c(0:NP-1,0:NAZMAX-1),dddbuff(0:NP-1)
      complex rph(0:NP-1,0:NAZMAX-1)               !range phase correction
      complex sinc_eval

      real*8 ph1, phc, r_q
      real*8 f0,f1,f2,f3           !doppler centroid function of range poly file 1
      real*8 r_ranpos(MP),r_azpos(MP),r_sig(MP),r_ranoff(MP)
      real*8 r_azoff(MP),r_rancoef(NPP),r_azcoef(NPP)
      real*8 r_v(NPP,NPP),r_u(MP,NPP),r_w(NPP),r_chisq
      real*8 r_ranpos2(MP),r_azpos2(MP),r_sig2(MP),r_ranoff2(MP)
      real*8 r_azoff2(MP),r_rancoef2(NPP),r_azcoef2(NPP)
      real*8 r_rancoef12(NPP)

      real*8 r_beta,r_relfiltlen,r_filter(0:MAXINTLGH),r_pedestal
      real*4 r_delay
      integer i_decfactor,i_weight,i_intplength,i_filtercoef

      real*4 t0, t1, t2, t3, t4, t5, t6
      real*4 seconds
      external seconds

c     COMMON BLOCKS:

      integer i_fitparam(NPP),i_coef(NPP)
      common /fred/ i_fitparam,i_coef 

c     EQUIVALENCE STATEMENTS:

c     DATA STATEMENTS:

c     FUNCTION STATEMENTS:

      integer rdflen
      external funcs
      character*255 rdfval,rdftmp

c     SAVE STATEMENTS:

      save b,c,am,bm,rph, r_ranpos,r_azpos,r_sig,r_ranoff, r_azoff, r_u
      save     r_ranpos2,r_azpos2,r_sig2,r_ranoff2, r_azoff2

c     PROCESSING STEPS:

cc      write(6,*) ' XXX start timer'
c      t0 = seconds(0.0)

      write(6,*) ' '       
      write(6,*)  ' << RTI Interpolation and Cross-correlation (quadratic) v1.0 >>'
      write(6,*) ' ' 

        if(iargc() .lt. 1)then
          write(6,'(a)') 'Usage: resamp_roi cmd_file'
          write(6,*) ' '
          stop
        endif

        call getarg(1,a_cmdfile)
      
      call rdf_init('ERRFILE=SCREEN')
      call rdf_init('ERROR_SCREEN=ON')
      call rdf_init('ERROR_OUTPUT=rdf_errors.log')
      call rdf_init('COMMENT= ! ! !')
      write(6,'(a)') 'Reading command file data...'
      call rdf_read(a_cmdfile)

c     read parameters from command file

      rdftmp=rdfval('Image Offset File Name','-')
      read(unit=rdftmp,fmt='(a)') a_offfile
      rdftmp=rdfval('Display Fit Statistics to Screen','-')
      read(unit=rdftmp,fmt='(a)') a_temp
      if(index(a_temp,'Show Fit Stats') .ne. 0)then
         istats = 1
      elseif(index(a_temp,'No Fit Stats') .ne. 0)then
         istats = 0
      endif
      rdftmp=rdfval('Number of Fit Coefficients','-')
      read(unit=rdftmp,fmt=*) i_ma
      rdftmp=rdfval('SLC Image File 1','-')
      read(unit=rdftmp,fmt='(a)') f(1)
      rdftmp=rdfval('Number of Range Samples Image 1','-')
      read(unit=rdftmp,fmt=*) npl
      rdftmp=rdfval('SLC Image File 2','-')
      read(unit=rdftmp,fmt='(a)') f(2)
      rdftmp=rdfval('Number of Range Samples Image 2','-')
      read(unit=rdftmp,fmt=*) npl2
      if((npl .gt. NP) .or. (npl2 .gt. NP)) then
         write(6,*) 'ERROR:number of pixels greater than array in resamp_roi'
         stop
      end if
      rdftmp=rdfval('Output Interferogram File','-')
      read(unit=rdftmp,fmt='(a)') f(3)
      rdftmp=rdfval('Multi-look Amplitude File','-')
      read(unit=rdftmp,fmt='(a)') f(4)
      rdftmp=rdfval('Starting Line, Number of Lines, and First Line Offset','-')
      read(unit=rdftmp,fmt=*) ist, nl, istoff
      rdftmp=rdfval('Doppler Cubic Fit Coefficients - PRF Units','-')
      read(unit=rdftmp,fmt=*) f0,f1,f2,f3
      rdftmp=rdfval('Radar Wavelength','m')
      read(unit=rdftmp,fmt=*) WVL
      rdftmp=rdfval('Slant Range Pixel Spacing','m')
      read(unit=rdftmp,fmt=*) SLR
      rdftmp=rdfval('Number of Range and Azimuth Looks','-')
      read(unit=rdftmp,fmt=*) NR,NAZ
      rdftmp=rdfval('Flatten with offset fit?','-')
      read(unit=rdftmp,fmt='(a)') a_temp

      iflatten = 2
      if(index(a_temp,'Yes') .ne. 0)then
         iflatten = 1
      elseif(index(a_temp,'No') .ne. 0)then
         iflatten = 0
      endif

c     open offset file

      write(6,*) ' '
      write(6,'(a,x,i5,x,i5)') 'Interferogram formed from lines: ',ist,ist+nl

      write(6,*) ' '
      write(6,'(a)') 'Opening file '//a_offfile(1:rdflen(a_offfile))

      open(13,file='resid.dat')
      open(unit=20,file=a_offfile, status='old',iostat=ierr)
      
      if (ierr .ne. 0) then 
         write(6,*) 'ERROR...correlation offsets file does not exist !'
         stop
      end if
      
      if(istats .eq. 1)then
         write(6,*) ' '
         write(6,*) ' Range    R offset     Azimuth    Az offset     SNR '
         write(6,*) '++++++++++++++++++++++++++++++++++++++++++++++++++++++++'
         write(6,*) ' '
      endif

c     reading offsets data file (note NS*NPM is maximal number of pixels)
      
      i_numpnts = 0
      i_na = 0
      do j=0,MP-1           !read the offset data file

         read(unit=20,FMT='(a)',end=50) as

         if(istats .eq. 1) write(6,'(a)') as
         
 3       if (as .ne. ' ')then

            i_numpnts = i_numpnts + 1
            read(as,*) lr,r_rt,iaz,r_at,r_st

            i_na = max(i_na,iaz)

c     stuff for two dimensional fits

            r_ranpos(i_numpnts) = float(lr)
            r_azpos(i_numpnts) = float(iaz)
            r_azoff(i_numpnts) = r_at
            r_ranoff(i_numpnts) = r_rt
            r_sig(i_numpnts) = 1.0 + 1.d0/r_st
            r_ranpos2(i_numpnts) = float(lr) + r_rt
            r_azpos2(i_numpnts) = float(iaz) + r_at
            r_azoff2(i_numpnts) = r_at
            r_ranoff2(i_numpnts) = r_rt
            r_sig2(i_numpnts) = 1.0 + 1.d0/r_st

         else

 5          read(unit=20,FMT='(a)',end=50) as    
            if(istats .eq. 1) write(6,'(a)') as
            if(as .eq. ' ') then  !read until non-blank line
               goto 5
            else
               goto 3
            end if
            
            if(istats .eq. 1) write(6,*) ' '
            
         end if
         
      end do

      write(6,*) 'ERROR: reached offset array size. '
      write(6,*) 'Number of offset points allowed =  ',MP
      stop 'Increase offset array size in program parameters'

 50   close(unit=20)            !close the file

      write(6,*) ' '
      write(6,*) 'Finished reading offset file...'
      write(6,*) 'Number of points read    =  ',i_numpnts
      write(6,*) 'Number of points allowed =  ',MP

c     find average int az off

      azsum = 0.
      azmin = r_azpos(1)
      do j=1,i_numpnts
         azsum = azsum + r_azoff(j)
         azmin = min(azmin,r_azpos(j))
      enddo
      azoff1 = azsum/i_numpnts
      int_az_off = nint(azoff1)
      write(6,*) ' '
      write(6,*) 'Average azimuth offset = ',azoff1,int_az_off
      
      do i = 1 , i_numpnts
         r_azpos(i) = r_azpos(i) - azmin
         r_azpos2(i) = r_azpos2(i) - int_az_off - azmin
      end do

c     make two two dimensional quadratic fits for the offset fields 
c     one of the azimuth offsets and the other for the range offsets

      do i = 1 , NPP
         r_rancoef(i) = 0.
         r_rancoef2(i) = 0.
         r_rancoef12(i) = 0.
         r_azcoef(i) = 0.
         r_azcoef2(i) = 0.
         i_coef(i) = 0
      end do

      do i=1,i_ma
         i_coef(i) = i
      enddo

c     azimuth offsets as a function range and azimuth

      call svdfit(r_ranpos,r_azpos,r_azoff,r_sig,i_numpnts,
     +     r_azcoef,i_ma,r_u,r_v,r_w,MP,NPP,r_chisq)

      write(6,*) 'Azimuth sigma = ',sqrt(r_chisq/i_numpnts)

c     inverse mapping azimuth offsets as a function range and azimuth

      call svdfit(r_ranpos2,r_azpos2,r_azoff2,r_sig2,i_numpnts,
     +     r_azcoef2,i_ma,r_u,r_v,r_w,MP,NPP,r_chisq)

      write(6,*) 'Inverse Azimuth sigma = ',sqrt(r_chisq/i_numpnts)

c     range offsets as a function of range and azimuth

      call svdfit(r_ranpos,r_azpos,r_ranoff,r_sig,i_numpnts,
     +     r_rancoef,i_ma,r_u,r_v,r_w,MP,NPP,r_chisq)

      write(6,*) 'Range sigma = ',sqrt(r_chisq/i_numpnts)

c     Inverse range offsets as a function of range and azimuth

      call svdfit(r_ranpos2,r_azpos2,r_ranoff2,r_sig2,i_numpnts,
     +     r_rancoef2,i_ma,r_u,r_v,r_w,MP,NPP,r_chisq)

      write(6,*) 'Inverse Range sigma = ',sqrt(r_chisq/i_numpnts)

c     Inverse range offsets as a function of range and azimuth

      call svdfit(r_ranpos,r_azpos2,r_ranoff2,r_sig2,i_numpnts,
     +     r_rancoef12,i_ma,r_u,r_v,r_w,MP,NPP,r_chisq)

      write(6,*) 'Inverse Range sigma = ',sqrt(r_chisq/i_numpnts)

      write(6,*) ' ' 
      write(6,*) 'Range offset fit parameters'
      write(6,*) ' '
      write(6,*) 'Constant term =            ',r_rancoef(1) 
      write(6,*) 'Range Slope term =         ',r_rancoef(2) 
      write(6,*) 'Azimuth Slope =            ',r_rancoef(3) 
      write(6,*) 'Range/Azimuth cross term = ',r_rancoef(4) 
      write(6,*) 'Range quadratic term =     ',r_rancoef(5) 
      write(6,*) 'Azimuth quadratic term =   ',r_rancoef(6) 
      write(6,*) 'Range/Azimuth^2   term =   ',r_rancoef(7) 
      write(6,*) 'Azimuth/Range^2 =          ',r_rancoef(8) 
      write(6,*) 'Range cubic term =         ',r_rancoef(9) 
      write(6,*) 'Azimuth cubic term =       ',r_rancoef(10) 
       
      write(6,*) ' ' 
      write(6,*) 'Azimuth offset fit parameters'
      write(6,*) ' '
      write(6,*) 'Constant term =            ',r_azcoef(1) 
      write(6,*) 'Range Slope term =         ',r_azcoef(2) 
      write(6,*) 'Azimuth Slope =            ',r_azcoef(3) 
      write(6,*) 'Range/Azimuth cross term = ',r_azcoef(4) 
      write(6,*) 'Range quadratic term =     ',r_azcoef(5) 
      write(6,*) 'Azimuth quadratic term =   ',r_azcoef(6) 
      write(6,*) 'Range/Azimuth^2   term =   ',r_azcoef(7) 
      write(6,*) 'Azimuth/Range^2 =          ',r_azcoef(8) 
      write(6,*) 'Range cubic term =         ',r_azcoef(9) 
      write(6,*) 'Azimuth cubic term =       ',r_azcoef(10) 

      write(6,*)
      write(6,*) 'Comparison of fit to actuals'
      write(6,*) ' '
      write(6,*) '   Ran       AZ    Ranoff    Ran fit  Rand Diff  Azoff    Az fit   Az Diff'

      rmean= 0.
      amean= 0.
      rsq= 0.
      asq= 0.
      do i=1,i_numpnts
         r_ro = r_rancoef(1) + r_azpos(i)*(r_rancoef(3) +
     +        r_azpos(i)*(r_rancoef(6) + r_azpos(i)*r_rancoef(10))) +   
     +        r_ranpos(i)*(r_rancoef(2) + r_ranpos(i)*(r_rancoef(5) +
     +        r_ranpos(i)*r_rancoef(9))) +
     +        r_ranpos(i)*r_azpos(i)*(r_rancoef(4) + r_azpos(i)*r_rancoef(7) +
     +        r_ranpos(i)*r_rancoef(8)) 
         r_ao = r_azcoef(1) + r_azpos(i)*(r_azcoef(3) +
     +        r_azpos(i)*(r_azcoef(6) + r_azpos(i)*r_azcoef(10))) +   
     +        r_ranpos(i)*(r_azcoef(2) + r_ranpos(i)*(r_azcoef(5) +
     +        r_ranpos(i)*r_azcoef(9))) +
     +        r_ranpos(i)*r_azpos(i)*(r_azcoef(4) + r_azpos(i)*r_azcoef(7) +
     +        r_ranpos(i)*r_azcoef(8)) 
         rmean = rmean + (r_ranoff(i)-r_ro)
         amean = amean + (r_azoff(i)-r_ao)
         rsq = rsq + (r_ranoff(i)-r_ro)**2
         asq = asq + (r_azoff(i)-r_ao)**2
         if(istats .eq. 1) write(6,150)  r_ranpos(i),r_azpos(i),r_ranoff(i),r_ro,r_ranoff(i)-r_ro,
     .        r_azoff(i),r_ao,r_azoff(i)-r_ao
 150     format(2(1x,f8.1),1x,f8.3,1x,f12.4,1x,f12.4,2x,f8.3,1x,f12.4
     $        ,1xf12.4,1x1x)

         write(13,269) int(r_ranpos(i)),r_ranoff(i)-r_ro,int(r_azpos(i))
     $        ,r_azoff(i)-r_ao,10.,1.,1.,0.

 269     format(i6,1x,f10.3,1x,i6,f10.3,1x,f10.5,3(1x,f10.6))

      enddo 
      rmean = rmean / i_numpnts
      amean = amean / i_numpnts
      rsq = sqrt(rsq/i_numpnts - rmean**2)
      asq = sqrt(asq/i_numpnts - amean**2)
      write(6,*) ' '
      write(6,'(a,x,f15.6,x,f15.6)') 'mean, sigma range   offset residual (pixels): ',rmean, rsq
      write(6,'(a,x,f15.6,x,f15.6)') 'mean, sigma azimuth offset residual (pixels): ',amean, asq
      
      write(6,*) ' ' 
      write(6,*) 'Range offset fit parameters'
      write(6,*) ' '
      write(6,*) 'Constant term =            ',r_rancoef2(1) 
      write(6,*) 'Range Slope term =         ',r_rancoef2(2) 
      write(6,*) 'Azimuth Slope =            ',r_rancoef2(3) 
      write(6,*) 'Range/Azimuth cross term = ',r_rancoef2(4) 
      write(6,*) 'Range quadratic term =     ',r_rancoef2(5) 
      write(6,*) 'Azimuth quadratic term =   ',r_rancoef2(6) 
      write(6,*) 'Range/Azimuth^2   term =   ',r_rancoef2(7) 
      write(6,*) 'Azimuth/Range^2 =          ',r_rancoef2(8) 
      write(6,*) 'Range cubic term =         ',r_rancoef2(9) 
      write(6,*) 'Azimuth cubic term =       ',r_rancoef2(10) 
       
      write(6,*) ' ' 
      write(6,*) 'Azimuth offset fit parameters'
      write(6,*) ' '
      write(6,*) 'Constant term =            ',r_azcoef2(1) 
      write(6,*) 'Range Slope term =         ',r_azcoef2(2) 
      write(6,*) 'Azimuth Slope =            ',r_azcoef2(3) 
      write(6,*) 'Range/Azimuth cross term = ',r_azcoef2(4) 
      write(6,*) 'Range quadratic term =     ',r_azcoef2(5) 
      write(6,*) 'Azimuth quadratic term =   ',r_azcoef2(6) 
      write(6,*) 'Range/Azimuth^2   term =   ',r_azcoef2(7) 
      write(6,*) 'Azimuth/Range^2 =          ',r_azcoef2(8) 
      write(6,*) 'Range cubic term =         ',r_azcoef2(9) 
      write(6,*) 'Azimuth cubic term =       ',r_azcoef2(10) 

      write(6,*)
      write(6,*) 'Comparison of fit to actuals'
      write(6,*) ' '
      write(6,*) '   Ran       AZ    Ranoff    Ran fit  Rand Diff  Azoff    Az fit   Az Diff'
      rmean= 0.
      amean= 0.
      rsq= 0.
      asq= 0.
      do i=1,i_numpnts
         r_ro = r_rancoef2(1) + r_azpos2(i)*(r_rancoef2(3) +
     +        r_azpos2(i)*(r_rancoef2(6) + r_azpos2(i)*r_rancoef2(10))) +   
     +        r_ranpos2(i)*(r_rancoef2(2) + r_ranpos2(i)*(r_rancoef2(5) +
     +        r_ranpos2(i)*r_rancoef2(9))) +
     +        r_ranpos2(i)*r_azpos2(i)*(r_rancoef2(4) + r_azpos2(i)*r_rancoef2(7) +
     +        r_ranpos2(i)*r_rancoef2(8)) 
         r_ao = r_azcoef2(1) + r_azpos2(i)*(r_azcoef2(3) +
     +        r_azpos2(i)*(r_azcoef2(6) + r_azpos2(i)*r_azcoef2(10))) +   
     +        r_ranpos2(i)*(r_azcoef2(2) + r_ranpos2(i)*(r_azcoef2(5) +
     +        r_ranpos2(i)*r_azcoef2(9))) +
     +        r_ranpos2(i)*r_azpos2(i)*(r_azcoef2(4) + r_azpos2(i)*r_azcoef2(7) +
     +        r_ranpos2(i)*r_azcoef2(8)) 
         rmean = rmean + (r_ranoff2(i)-r_ro)
         amean = amean + (r_azoff2(i)-r_ao)
         rsq = rsq + (r_ranoff2(i)-r_ro)**2
         asq = asq + (r_azoff2(i)-r_ao)**2
         if(istats .eq. 1) write(6,150)  r_ranpos2(i),r_azpos2(i),r_ranoff(i),r_ro,r_ranoff2(i)-r_ro,
     .        r_azoff2(i),r_ao,r_azoff2(i)-r_ao
         write(13,269) int(r_ranpos2(i)),r_ranoff2(i)-r_ro,int(r_azpos2(i))
     $        ,r_azoff2(i)-r_ao,10.,1.,1.,0.


       enddo 
       rmean = rmean / i_numpnts
       amean = amean / i_numpnts
       rsq = sqrt(rsq/i_numpnts - rmean**2)
       asq = sqrt(asq/i_numpnts - amean**2)
       write(6,*) ' '
       write(6,'(a,x,f15.6,x,f15.6)') 'mean, sigma range   offset residual (pixels): ',rmean, rsq
       write(6,'(a,x,f15.6,x,f15.6)') 'mean, sigma azimuth offset residual (pixels): ',amean, asq

       
c     read in the data file to be resampled 

      inquire(file=f(1),exist=ex)
      if (.not.ex) then 
         write(6,*) 'ERROR...file does not exist !'
         stop
      end if

      write(6,*) 'XXX unit=21, file=(1): ', f(1)
      open(unit=21,file=f(1),form='unformatted',status='old',access='direct',recl=8*npl)
      
      nplo = min(npl,npl2)
      write(6,*) ' '
      write(6,'(a,x,i5)') 'Number samples in interferogram: ',nplo/NR

      write(6,*) 'XXX unit=23, file=(3): ', f(3)
        open(unit=23, file=f(3), form='unformatted', status='unknown', access='direct',recl=(nplo/NR)*8)

      CPP=SLR/WVL

      i_a1 = i_na - azmin
      i_r1 = npl/2.
      rphs  = 360. * 2. * CPP * (r_rancoef(2) + i_a1*(r_rancoef(4) + 
     +     r_rancoef(7)*i_a1) + i_r1*(2.*r_rancoef(5) +
     $     3.*r_rancoef(9)*i_r1 + 2.*r_rancoef(8)*i_a1))

      write(6,*) ' '
      write(6,'(a,x,3(f15.6,x))') 'Pixel shift/pixel in range    = ',rphs/(CPP*360.),aa1,sngl(r_rancoef(2))
      write(6,'(a,x,3(f15.6,x))') 'Degrees per pixel range shift = ',rphs,rphs1,2.*sngl(r_rancoef(2)*CPP*360.)

      if(f0 .eq. -99999.)then
         write(6,*) ' '
         write(6,*) 'Estimating Doppler from input file...' 
         l1 = 1
         l2 = nb
         do j=l1-1,l2-1
            if(mod(j,100) .eq. 0)then
               write(6,*) 'Reading file at line = ',j
            endif
            read(21,rec=j+1) (b(i,j),i=0,npl-1)
         enddo 
         call doppler(npl,l1,l2,b,fd,dddbuff)
         do j=0,npl-1
            write(66,*) j,fd(j)
         enddo
      endif

c     compute resample coefficients 
      
      r_beta = 1.d0
      r_relfiltlen = 8.d0
      i_decfactor = 8192
      r_pedestal = 0.d0
      i_weight = 1
      
      write(6,*) ' '
      write(6,'(a)') 'Computing sinc coefficients...'
      write(6,*) ' '
      
      call sinc_coef(r_beta,r_relfiltlen,i_decfactor,r_pedestal,i_weight,
     +     i_intplength,i_filtercoef,r_filter)
      
      r_delay = i_intplength/2.d0
      f_delay = r_delay
      
      do i = 0 , i_intplength - 1
         do j = 0 , i_decfactor - 1
            fintp(i+j*i_intplength) = r_filter(j+i*i_decfactor)
         enddo
      enddo

      nb = NBMAX
      ibfcnt = (NBMAX-2*N_OVER)/NAZ
      ibfcnt = ibfcnt * NAZ
      nb = ibfcnt + 2*N_OVER

      if(nb .ne. NBMAX) then
         write(6,*) 'Modified buffer max to provide sync-ed overlap'
         write(6,*) 'Max buffer size = ',NBMAX
         write(6,*) 'Set buffer size = ',nb
      end if

c     begin resampling

      write(6,'(a)') 'Beginning resampling...'
      write(6,*) ' '
      
      ibfcnt = nb-2*N_OVER

cc XXX Start of line loop
      do line=0,nl/NAZ-1

         lc = line*NAZ
         ibfcnt = ibfcnt + NAZ
         
         if(ibfcnt .ge. nb-2*N_OVER) then

            ibfcnt = 0
            ibs = ist+int_az_off-N_OVER+lc/(nb-2*N_OVER)*(nb-2*N_OVER)
            ibe = ibs+nb-1

            write(6,'(a,x,i5,x,i5,x,i5,x,i5,x,i5)') 
     +           'int line, slc line, buffer #, line start, line end: ',
     +           line,lc,lc/(nb-2*N_OVER)+1,ibs,ibe
            write(6,'(a,i5,a)') 'Reading ',nb,' lines of data'

            do i=0, nb-1        !load up  buffer

               if(mod(i+1,1000) .eq. 0)then
                  write(6,'(a,x,i10)') 'At line: ',i+1
               endif

               irec = i + ibs
               jrec = irec + istoff - 1  ! irec,jrec = image 2 coordinates
               jrecp = jrec - int_az_off - azmin ! subtract big constant for fit

               if(irec .gt. 0)then       !in the data?

                  if(irec .gt. nl+ist+int_az_off)then
                     go to 900
                  endif
                  read(UNIT=21,REC=irec,iostat=ierr) (tmp(ii),ii=0,npl-1) 
                  if(ierr .ne. 0) goto 900
                  
c*    calculate range interpolation factors, which depend on range and azimuth
c*    looping over IMAGE COORDINATES.

                  do j=0,nplo-1 
                     r_ro = r_rancoef12(1) + jrecp*(r_rancoef12(3) +
     +                    jrecp*(r_rancoef12(6) + jrecp*r_rancoef12(10))) +   
     +                    j*(r_rancoef12(2) + j*(r_rancoef12(5) +
     +                    j*r_rancoef12(9))) +
     +                    j*jrecp*(r_rancoef12(4) + jrecp*r_rancoef12(7) +
     +                    j*r_rancoef12(8)) 
                     rd = r_ro + j 
                     int_rd(j)=int(rd+f_delay)
                     fr_rd(j)=rd+f_delay-int_rd(j)
                  end do
                  do j=0,nplo-1  !range interpolate
                     b(j,i)= sinc_eval(tmp,npl2,fintp,8192,8,int_rd(j),fr_rd(j))
                  end do

               else

                  do j=0,nplo-1  !fill with 0, no data yet
                     b(j,i)=(0.,0.)
                  end do

               end if  

            end do     !i loop

            goto 901            !jump around this code to fill

 900        write(6,'(a,x,i5)') 'Filling last block, line: ',i

            do ii=i,nb-1
               do j=0,nplo-1
                  b(j,ii)=(0.,0.)
               end do
            end do

 901        continue

         end if

         do k=0,NAZ-1
            irec = ist + line*NAZ + k
            jrec = irec + istoff - azmin - 1

c note: this is only half the phase! Some for each channel

            do j=0,nplo-1
               r_ro = r_rancoef(1) + jrec*(r_rancoef(3) +
     +              jrec*(r_rancoef(6) + jrec*r_rancoef(10))) +   
     +              j*(r_rancoef(2) + j*(r_rancoef(5) +
     +              j*r_rancoef(9))) +
     +              j*jrec*(r_rancoef(4) + jrec*r_rancoef(7) +
     +              j*r_rancoef(8)) 
               r_ao = r_azcoef(1) + jrec*(r_azcoef(3) +
     +              jrec*(r_azcoef(6) + jrec*r_azcoef(10))) +   
     +              j*(r_azcoef(2) + j*(r_azcoef(5) +
     +              j*r_azcoef(9))) +
     +              j*jrec*(r_azcoef(4) + jrec*r_azcoef(7) +
     +              j*r_azcoef(8)) 

c*    !calculate azimuth offsets

               azs = irec + r_ao 
c               int_az(j) = nint(azs)
               if(azs .ge. 0.d0) then
                  int_az(j) = int(azs)
               else
                  int_az(j) = int(azs) - 1
               end if
               fr_az(j) = azs - int_az(j)
               rph(j,k)=cmplx(cos(sngl(2.*pi*r_ro*CPP)),-sin(sngl(2.*pi*r_ro*CPP)))

            end do

            do j=0,npl-1
               a(j) = tmp(j)*rph(j,k)
            end do
            
            do j=0,nplo-1        !azimuth interpolation
               ix = int_az(j)-ibs
               r_q  = (f0  + f1*j  + f2*j**2 + f3*j**3) 
c               write(*,*) 'r_q 1', r_q
               r_q = (((f3 * j + f2) * j) + f1) * j + f0
c               write(*,*) 'r_q 2', r_q
               ph1 = (r_q)*2.0*PI
               phc = fr_az(j) * ph1
               do ii = -3, 4
                  tmp(ii+3) = b(j,ix+ii) * cmplx(cos(ii*ph1),-sin(ii*ph1
     $                 ))
               end do
               cm(j) = sinc_eval(tmp,8,fintp,8192,8,7,fr_az(j))
               cm(j) = cm(j) * conjg(rph(j,k)) * cmplx(cos(phc),
     $              +sin(phc))

            end do
            dm(nplo-1) = a(nplo-1)
            dm(0) = a(0)
            em(nplo-1) = cm(nplo-1)
            em(0) = cm(0)
            do j = 1, nplo-2
               dm(j) = .23*a(j-1)+a(j)*.54+a(j+1)*.23
               em(j) = .23*cm(j-1)+cm(j)*.54+cm(j+1)*.23
            end do
            
         end do

         write(UNIT=23,rec=line+1)(em(ii),ii=0,nplo/NR-1) !write out

      end do
cc XXX End of line loop

c      t1 = seconds(t0)
      write(6,*) 'XXX time: ', t1-t0

 1000 close(UNIT=21)
      close(UNIT=22)
      close(UNIT=23)
      close(UNIT=24)

      end
      

      subroutine funcs(x,y,afunc,ma)
      
      real*8 afunc(ma),x,y
      real*8 cf(10)
      integer i_fitparam(10),i_coef(10)
      
      common /fred/ i_fitparam,i_coef
      
      data cf /10*0./
      
      do i=1,ma
         cf(i_coef(i))=1.
         afunc(i) = cf(1) + x*(cf(2) + x*(cf(5) + x*cf(9))) + 
     +        y*(cf(3) + y*(cf(6) + y*cf(10))) +
     +        x*y*(cf(4) + y*cf(7) + x*cf(8))  
         cf(i_coef(i))=0.
      end do
      
      return
      end    

      subroutine intp_coefg(psfilename,dec_fac,intp_lgt,f_delay,fintp)
      
      implicit none
      
      integer fl_lgt
      parameter (fl_lgt=8*8192)

      real*8        yintp(0:FL_LGT-1)
      real*4        fintp(0:FL_LGT-1),f_delay
      integer*4     i,j
      integer*4     dec_fac, intp_lgt, k
      real*8        av,dc_max,dc_min
      character*(*) psfilename

      if(dec_fac*intp_lgt .gt. FL_LGT) then
         write(6,*)
     $        'intp_coefg: insufficient space allocated for filter'
         stop
      end if

      open(88,file=psFilename,recl=8*dec_fac*intp_lgt,access='direct')
      read(88,rec=1) (yintp(k),k = 1,dec_fac*intp_lgt)
      close(88)

      do i=0,intp_lgt-1
         do j=0,dec_fac-1
            fintp(i + j*intp_lgt) = yintp(j + i*dec_fac)
         end do
      end do

c f_delay is chosen below "incorrectly" because of the bias introduced
c in the code by choosing the integer index smaller than the actual index
c i.e. ifrac = int(frac*dec_fac)  biases the delay downward
c
c      f_delay =  (float(dec_fac*intp_lgt)/2.-0.5)/float(dec_fac)
c
      f_delay =  (float(dec_fac*intp_lgt)/2.)/float(dec_fac)

c      write(6,*) 'f_delay    = ',f_delay
      
      dc_max = 0.0
      dc_min = 9.9
      do j = 0,dec_fac-1
         av = 0.0
         do i = 0,intp_lgt-1
            av = av + fintp(i + j*intp_lgt)
         enddo
         dc_min = min(dc_min,av)
         dc_max = max(dc_max,av)
      enddo
      av = 0.5 * (dc_max+dc_min)
      do j=0,dec_fac*intp_lgt-1
         fintp(j) = fintp(j)/av
      end do
      
c      write(6,*) 'dc_min   = ',dc_min/av
c      write(6,*) 'dc_max   = ',dc_max/av
      
      return
      end
      
      complex*8 function sinc_eval(arrin,nsamp,intarr,idec,ilen,intp,frp)
      
      integer ilen,idec,intp, nsamp
      real*8 frp
      complex arrin(0:nsamp-1)
      real*4 intarr(0:idec*ilen-1)

      sinc_eval = cmplx(0.,0.)
      if(intp .ge. ilen-1 .and. intp .lt. nsamp ) then
         ifrac= min(max(0,int(frp*idec)),idec-1)
         do k=0,ilen-1
            sinc_eval = sinc_eval + arrin(intp-k)*
     +           intarr(k + ifrac*ilen)
         enddo
      end if

      end


c****************************************************************

      subroutine sinc_coef(r_beta,r_relfiltlen,i_decfactor,r_pedestal,
     +     i_weight,i_intplength,i_filtercoef,r_filter)

c****************************************************************
c**     
c**   FILE NAME: sinc_coef.f
c**     
c**   DATE WRITTEN: 10/15/97
c**     
c**   PROGRAMMER: Scott Hensley
c**     
c**   FUNCTIONAL DESCRIPTION: The number of data values in the array 
c**   will always be the interpolation length * the decimation factor, 
c**   so this is not returned separately by the function.
c**     
c**   ROUTINES CALLED:
c**     
c**   NOTES: 
c**     
c**   UPDATE LOG:
c**
c**   Date Changed        Reason Changed                  CR # and Version #
c**   ------------       ----------------                 -----------------
c**     
c*****************************************************************

      implicit none

c     INPUT VARIABLES:

      real*8 r_beta             !the "beta" for the filter
      real*8 r_relfiltlen       !relative filter length
      integer i_decfactor       !the decimation factor
      real*8 r_pedestal         !pedestal height
      integer i_weight          !0 = no weight , 1=weight
	
c     OUTPUT VARIABLES:
      
      integer i_intplength      !the interpolation length
      integer i_filtercoef      !number of coefficients
      real*8 r_filter(*)        !an array of data values 

c     LOCAL VARIABLES:

      real*8 r_alpha,pi,r_wgt,r_s,r_fct,r_wgthgt,r_soff,r_wa
      integer i_psfl,i,j,ii

c     COMMON BLOCKS:

c     EQUIVALENCE STATEMENTS:

c     DATA STATEMENTS:

C     FUNCTION STATEMENTS:

c     PROCESSING STEPS:

      pi = 4.d0*atan(1.d0)

c     number of coefficients

      i_intplength = nint(r_relfiltlen/r_beta)
      i_filtercoef = i_intplength*i_decfactor
      r_wgthgt = (1.d0 - r_pedestal)/2.d0
      r_soff = (i_filtercoef - 1.d0)/2.d0
      
      do i=0,i_filtercoef-1
         r_wa = i - r_soff
         r_wgt = (1.d0 - r_wgthgt) + r_wgthgt*cos((pi*r_wa)/r_soff)
         j = i - (i_filtercoef - 1.d0)/2.d0
         r_s = dble(j)*r_beta/dble(i_decfactor)
         if(r_s .ne. 0.0)then
            r_fct = sin(pi*r_s)/(pi*r_s)
         else
            r_fct = 1.0
         endif
         if(i_weight .eq. 1)then
            r_filter(i+1) = r_fct*r_wgt
         else
            r_filter(i+1) = r_fct
         endif
      enddo

      end

cc-------------------------------------------

      real*4 function seconds(t0)
      real*4 t0
      real*8 secondo

c      seconds = secondo(-1) - t0

      return
      end

