c  fitoffset - fit offset output file to 2-d plane for across, down

      parameter (NTERMS=6)	
      parameter (MP=10000)
      parameter (NPP=6)

      character*30 file

      real*8  xd(MP),yd(MP),sig(MP),acshift(MP),dnshift(MP),s(MP)
      real*8  coef(NPP),v(NPP,NPP),u(MP,NPP),w(NPP)
      real*8  chisq

      real*4  acresidual(MP),dnresidual(MP)

      integer icoef(10)
      common /coefcomm/icoef

      if(iargc().lt.1)then
         write(*,*)'usage: fitoffset offsetfile'
         stop
      end if
      call getarg(1,file)

      snrmin=0.

 98   open(21,file=file,form='formatted',status='unknown')
      nn=0
      do i=1,MP
         read(21,*,end=99)iac,offac,idn,offdn,snr
         if(snr.ge.snrmin)then
         nn=nn+1
         xd(nn)=iac
         yd(nn)=idn
         acshift(nn)=offac
         dnshift(nn)=offdn
         sig(nn)=1.
         s(nn)=snr
         end if
      end do
c     get mean, standard deviation of raw data
 99   close(21)
      aveac=0.
      avedn=0.
      aveac2=0.
      avedn2=0.
      do i=1,nn
         aveac=aveac+acshift(i)
         avedn=avedn+dnshift(i)
         aveac2=aveac2+acshift(i)**2
         avedn2=avedn2+dnshift(i)**2
      end do
      aveac=aveac/nn
      avedn=avedn/nn
      stdvac=sqrt(aveac2/nn-aveac**2)
      stdvdn=sqrt(avedn2/nn-avedn**2)
      write(*,*)'Raw across mean, standard deviation: ',aveac,stdvac
      write(*,*)'Raw down mean, standard deviation:   ',avedn,stdvdn

c     fit across shifts, 2D dependence
      ma=3
      icoef(1)=1
      icoef(2)=2
      icoef(3)=3
      call svdfit(xd,yd,acshift,sig,nn,coef,ma,u,v,w,MP,NPP,chisq)
c     write(*,*)'chi square: ',chisq
c     write(*,*)'coefficients: '
c     do j=1,ma
c     write(*,*)j,coef(j)
c     end do

      slpdn=coef(2)
      slpac=coef(3)
      c=coef(1)
      write(*,*)
      write(*,*)'         Slope down  Slope across  Intercept: '
      write(*,*)'Across: ',slpdn,slpac,c

      do n=1,nn
c     acest=coef(6)*(xd(n)**2)+coef(5)*(yd(n)**2)+
c     +              coef(4)*xd(n)*yd(n)+ 
c     +              coef(3)*xd(n)+coef(2)*yd(n)+coef(1)
         acest=coef(3)*xd(n)+coef(2)*yd(n)+coef(1)
         acresidual(n)=acshift(n)-acest
      end do

c     fit down shifts
      call svdfit(xd,yd,dnshift,sig,nn,coef,ma,u,v,w,MP,NPP,chisq)

      slpdn=coef(2)
      slpac=coef(3)
      c=coef(1)
      write(*,*)
      write(*,*)'Down:   ',slpdn,slpac,c
      write(*,*)

      do n=1,nn
c     acest=coef(6)*(xd(n)**2)+coef(5)*(yd(n)**2)+
c     +              coef(4)*xd(n)*yd(n)+ 
c     +              coef(3)*xd(n)+coef(2)*yd(n)+coef(1)
         dnest=coef(3)*xd(n)+coef(2)*yd(n)+coef(1)
         dnresidual(n)=dnshift(n)-dnest
      end do

c  tabulate residuals
      write(*,*)'Across, Down loc Across, Down shift Across, Down residual SNR'
      do i=1,nn
         print '(1x,2f7.0,2f9.2,3f9.2)',xd(i),yd(i),acshift(i),
     +        dnshift(i),acresidual(i),dnresidual(i),s(i)
      end do
      write(*,*)

c     get mean, standard deviation of residuals across, down
      aveac=0.
      avedn=0.
      aveac2=0.
      avedn2=0.
      do i=1,nn
         aveac=aveac+acresidual(i)
         avedn=avedn+dnresidual(i)
         aveac2=aveac2+acresidual(i)**2
         avedn2=avedn2+dnresidual(i)**2
      end do
      aveac=aveac/nn
      avedn=avedn/nn
      stdvac=sqrt(aveac2/nn-aveac**2)
      stdvdn=sqrt(avedn2/nn-avedn**2)
      write(*,*)'Residual across mean, standard deviation: ',aveac,stdvac
      write(*,*)'Residual down mean, standard deviation:   ',avedn,stdvdn

c     fit across shifts, 1D down dependence
      ma=2
      icoef(1)=1
      icoef(2)=2
      icoef(3)=3
      call svdfit(xd,yd,acshift,sig,nn,coef,ma,u,v,w,MP,NPP,chisq)

      slpac=coef(2)
      cac=coef(1)
      write(*,*)
      write(*,*)'1-D calculation: '
      write(*,*)
      write(*,*)'         Slope down  Intercept: '
      write(*,*)'Across: ',slpac,cac

c     fit down shifts, 1D down dependence
      ma=2
      icoef(1)=1
      icoef(2)=2
      icoef(3)=3
      call svdfit(xd,yd,dnshift,sig,nn,coef,ma,u,v,w,MP,NPP,chisq)

      slpdn=coef(2)
      cdn=coef(1)
      write(*,*)'Down:   ',slpdn,cdn

      print '(a,$)','Remove points with snr < ? (neg snr exits) '
      read(*,*)snrmin
      if(snrmin.ge.0)go to 98
      print '(a,$)','Number of patches divisor ? '
      read(*,*)n
      write(*,*)'         Slope down  Intercept: '
      write(*,*)'Across: ',slpac/n,cac/n
      write(*,*)'Down:   ',slpdn/n,cdn/n
      

      end


	 subroutine funcs(x,y,afunc,ma)

         integer icoef(10)
         common /coefcomm/icoef


         real*8 afunc(ma),x,y
         real*8 cf(10)

         data cf( 1) /0./
         data cf( 2) /0./
         data cf( 3) /0./
         data cf( 4) /0./
         data cf( 5) /0./
         data cf( 6) /0./
         data cf( 7) /0./
         data cf( 8) /0./
         data cf( 9) /0./
         data cf( 10) /0./

        do i=1,ma
             cf(icoef(i))=1.
             afunc(i)=cf(6)*(x**2)+cf(5)*(y**2)+cf(4)*x*y+ 
     +                cf(3)*x+cf(2)*y+cf(1)
             cf(i)=0.
        end do

	return
	end    

      subroutine svdfit(x,y,z,sig,ndata,a,ma,u,v,w,mp,np,chisq)
      implicit real*8 (a-h,o-z)
      parameter(nmax=300000,mmax=6,tol=1.e-6)
      dimension x(ndata),y(ndata),z(ndata),sig(ndata),a(ma),v(np,np),
     *    u(mp,np),w(np),b(nmax),afunc(mmax)
c      write(*,*)'evaluating basis functions...'
      do 12 i=1,ndata
        call funcs(x(i),y(i),afunc,ma)
        tmp=1./sig(i)
        do 11 j=1,ma
          u(i,j)=afunc(j)*tmp
11      continue
        b(i)=z(i)*tmp
12    continue
c      write(*,*)'SVD...'
      call svdcmp(u,ndata,ma,mp,np,w,v)
      wmax=0.
      do 13 j=1,ma
        if(w(j).gt.wmax)wmax=w(j)
13    continue
      thresh=tol*wmax
c	write(*,*)'eigen value threshold',thresh
      do 14 j=1,ma
c	write(*,*)j,w(j)
        if(w(j).lt.thresh)w(j)=0.
14    continue
c      write(*,*)'calculating coefficients...'
      call svbksb(u,w,v,ndata,ma,mp,np,b,a)
      chisq=0.
c      write(*,*)'evaluating chi square...'
      do 16 i=1,ndata
        call funcs(x(i),y(i),afunc,ma)
        sum=0.
        do 15 j=1,ma
          sum=sum+a(j)*afunc(j)
15      continue
        chisq=chisq+((z(i)-sum)/sig(i))**2
16    continue
      return
      end

      subroutine svbksb(u,w,v,m,n,mp,np,b,x)
      implicit real*8 (a-h,o-z)
      parameter (nmax=100)
      dimension u(mp,np),w(np),v(np,np),b(mp),x(np),tmp(nmax)
      do 12 j=1,n
        s=0.
        if(w(j).ne.0.)then
          do 11 i=1,m
            s=s+u(i,j)*b(i)
11        continue
          s=s/w(j)
        endif
        tmp(j)=s
12    continue
      do 14 j=1,n
        s=0.
        do 13 jj=1,n
          s=s+v(j,jj)*tmp(jj)
13      continue
        x(j)=s
14    continue
      return
      end

      subroutine svdcmp(a,m,n,mp,np,w,v)
      implicit real*8 (a-h,o-z)
      parameter (nmax=100)
      dimension a(mp,np),w(np),v(np,np),rv1(nmax)
      g=0.0
      scale=0.0
      anorm=0.0
      do 25 i=1,n
        l=i+1
        rv1(i)=scale*g
        g=0.0
        s=0.0
        scale=0.0
        if (i.le.m) then
          do 11 k=i,m
            scale=scale+abs(a(k,i))
11        continue
          if (scale.ne.0.0) then
            do 12 k=i,m
              a(k,i)=a(k,i)/scale
              s=s+a(k,i)*a(k,i)
12          continue
            f=a(i,i)
            g=-sign(sqrt(s),f)
            h=f*g-s
            a(i,i)=f-g
            if (i.ne.n) then
              do 15 j=l,n
                s=0.0
                do 13 k=i,m
                  s=s+a(k,i)*a(k,j)
13              continue
                f=s/h
                do 14 k=i,m
                  a(k,j)=a(k,j)+f*a(k,i)
14              continue
15            continue
            endif
            do 16 k= i,m
              a(k,i)=scale*a(k,i)
16          continue
          endif
        endif
        w(i)=scale *g
        g=0.0
        s=0.0
        scale=0.0
        if ((i.le.m).and.(i.ne.n)) then
          do 17 k=l,n
            scale=scale+abs(a(i,k))
17        continue
          if (scale.ne.0.0) then
            do 18 k=l,n
              a(i,k)=a(i,k)/scale
              s=s+a(i,k)*a(i,k)
18          continue
            f=a(i,l)
            g=-sign(sqrt(s),f)
            h=f*g-s
            a(i,l)=f-g
            do 19 k=l,n
              rv1(k)=a(i,k)/h
19          continue
            if (i.ne.m) then
              do 23 j=l,m
                s=0.0
                do 21 k=l,n
                  s=s+a(j,k)*a(i,k)
21              continue
                do 22 k=l,n
                  a(j,k)=a(j,k)+s*rv1(k)
22              continue
23            continue
            endif
            do 24 k=l,n
              a(i,k)=scale*a(i,k)
24          continue
          endif
        endif
        anorm=max(anorm,(abs(w(i))+abs(rv1(i))))
25    continue
      do 32 i=n,1,-1
        if (i.lt.n) then
          if (g.ne.0.0) then
            do 26 j=l,n
              v(j,i)=(a(i,j)/a(i,l))/g
26          continue
            do 29 j=l,n
              s=0.0
              do 27 k=l,n
                s=s+a(i,k)*v(k,j)
27            continue
              do 28 k=l,n
                v(k,j)=v(k,j)+s*v(k,i)
28            continue
29          continue
          endif
          do 31 j=l,n
            v(i,j)=0.0
            v(j,i)=0.0
31        continue
        endif
        v(i,i)=1.0
        g=rv1(i)
        l=i
32    continue
      do 39 i=n,1,-1
        l=i+1
        g=w(i)
        if (i.lt.n) then
          do 33 j=l,n
            a(i,j)=0.0
33        continue
        endif
        if (g.ne.0.0) then
          g=1.0/g
          if (i.ne.n) then
            do 36 j=l,n
              s=0.0
              do 34 k=l,m
                s=s+a(k,i)*a(k,j)
34            continue
              f=(s/a(i,i))*g
              do 35 k=i,m
                a(k,j)=a(k,j)+f*a(k,i)
35            continue
36          continue
          endif
          do 37 j=i,m
            a(j,i)=a(j,i)*g
37        continue
        else
          do 38 j= i,m
            a(j,i)=0.0
38        continue
        endif
        a(i,i)=a(i,i)+1.0
39    continue
      do 49 k=n,1,-1
        do 48 its=1,30
          do 41 l=k,1,-1
            nm=l-1
            if ((abs(rv1(l))+anorm).eq.anorm)  go to 2
            if ((abs(w(nm))+anorm).eq.anorm)  go to 1
41        continue
1         c=0.0
          s=1.0
          do 43 i=l,k
            f=s*rv1(i)
            if ((abs(f)+anorm).ne.anorm) then
              g=w(i)
              h=sqrt(f*f+g*g)
              w(i)=h
              h=1.0/h
              c= (g*h)
              s=-(f*h)
              do 42 j=1,m
                y=a(j,nm)
                z=a(j,i)
                a(j,nm)=(y*c)+(z*s)
                a(j,i)=-(y*s)+(z*c)
42            continue
            endif
43        continue
2         z=w(k)
          if (l.eq.k) then
            if (z.lt.0.0) then
              w(k)=-z
              do 44 j=1,n
                v(j,k)=-v(j,k)
44            continue
            endif
            go to 3
          endif
          if (its.eq.30) pause 'no convergence in 30 iterations'
          x=w(l)
          nm=k-1
          y=w(nm)
          g=rv1(nm)
          h=rv1(k)
          f=((y-z)*(y+z)+(g-h)*(g+h))/(2.0*h*y)
          g=sqrt(f*f+1.0)
          f=((x-z)*(x+z)+h*((y/(f+sign(g,f)))-h))/x
          c=1.0
          s=1.0
          do 47 j=l,nm
            i=j+1
            g=rv1(i)
            y=w(i)
            h=s*g
            g=c*g
            z=sqrt(f*f+h*h)
            rv1(j)=z
            c=f/z
            s=h/z
            f= (x*c)+(g*s)
            g=-(x*s)+(g*c)
            h=y*s
            y=y*c
            do 45 nm=1,n
              x=v(nm,j)
              z=v(nm,i)
              v(nm,j)= (x*c)+(z*s)
              v(nm,i)=-(x*s)+(z*c)
45          continue
            z=sqrt(f*f+h*h)
            w(j)=z
            if (z.ne.0.0) then
              z=1.0/z
              c=f*z
              s=h*z
            endif
            f= (c*g)+(s*y)
            x=-(s*g)+(c*y)
            do 46 nm=1,m
              y=a(nm,j)
              z=a(nm,i)
              a(nm,j)= (y*c)+(z*s)
              a(nm,i)=-(y*s)+(z*c)
46          continue
47        continue
          rv1(l)=0.0
          rv1(k)=f
          w(k)=x
48      continue
3       continue
49    continue
      return
      end
