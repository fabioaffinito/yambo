!
!        Copyright (C) 2000-2018 the YAMBO team
!              http://www.yambo-code.org
!
! Authors (see AUTHORS file for details): AM
! 
! This file is distributed under the terms of the GNU 
! General Public License. You can redistribute it and/or 
! modify it under the terms of the GNU General Public 
! License as published by the Free Software Foundation; 
! either version 2, or (at your option) any later version.
!
! This program is distributed in the hope that it will 
! be useful, but WITHOUT ANY WARRANTY; without even the 
! implied warranty of MERCHANTABILITY or FITNESS FOR A 
! PARTICULAR PURPOSE.  See the GNU General Public License 
! for more details.
!
! You should have received a copy of the GNU General Public 
! License along with this program; if not, write to the Free 
! Software Foundation, Inc., 59 Temple Place - Suite 330,Boston, 
! MA 02111-1307, USA or visit http://www.gnu.org/copyleft/gpl.txt.
!
subroutine QP_newton(X,Xen,Xk,en,k,q,qp,Xw)
 !
 use pars,          ONLY:SP,cZERO
 use units,         ONLY:HA2EV
 use drivers,       ONLY:l_ppa,l_elel_corr,l_cohsex
 use com,           ONLY:msg
 use X_m,           ONLY:X_t
 use QP_m,          ONLY:QP_t,QP_dSc_steps,QP_Vnl_xc,QP_Vxc,QP_Sc,&
&                        QP_n_states,QP_dSc,QP_dSc_delta,QP_n_G_bands,&
&                        GWo_SC_done,GWo_iterations,SC_E_threshold,On_Mass_Shell_approx
 use frequency,     ONLY:w_samp
 use electrons,     ONLY:levels
 use R_lattice,     ONLY:bz_samp
 use QP_CTL_m,      ONLY:QP_apply
#if defined _ELPH
 use drivers,       ONLY:l_elph_corr
#endif
 implicit none
 type(levels) ::en,Xen
 type(bz_samp)::Xk,k,q
 type(X_t)    ::X
 type(QP_t)   ::qp
 type(w_samp) ::Xw
 !
 ! Work Space
 !
 integer     :: i1,i2,iter
 real(SP)    :: SC_corr_prev,SC_corr_now
 complex(SP) :: Z(QP_dSc_steps-1),Eqp(QP_dSc_steps-1)
 !
 ! Dyson equation: Newton solver 
 !
 if (l_cohsex) then
   !
   call msg('r', '[Newton] Sc step   [ev]:',QP_dSc_delta*HA2EV)
   call msg('r', '[Newton] Sc steps      :',QP_dSc_steps)
   !
 endif
 !
 call msg('rn','[Newton] SC iterations :',GWo_iterations)
 !
 iter=0
 SC_corr_prev=1._SP
 !
   !
   if (l_elel_corr) then
     if (l_ppa.or.l_cohsex) then
       !
       call QP_ppa_cohsex(X,Xk,en,k,q,qp,Xw,iter)
       !
     else 
       !
       call QP_real_axis(X,Xen,Xk,en,k,q,qp,Xw,iter)
       !
     endif
   else
     QP_Sc=cZERO
   endif
   !
# if defined _ELPH 
   !
   if (l_elph_corr)     call ELPH_Sigma_c(en,k,q,qp)
   !
#endif
   !
   !
   do i1=1,QP_n_states
     !
     if(.not.l_cohsex) then
       !     
         !
         QP_dSc(i1,1)=cZERO
         !     
         if (.not.On_Mass_Shell_approx) then
           do i2=1,QP_dSc_steps-1
             QP_dSc(i1,i2)=(QP_Sc(i1,i2+1)-QP_Sc(i1,i2))/QP_dSc_delta
           enddo
         endif
         !
       !
       do i2=1,QP_dSc_steps-1
         !
         Z(i2)=1._SP/(1._SP-QP_dSc(i1,i2))
         !
         Eqp(i2)=qp%E_bare(i1)+Z(i2)*QP_Sc(i1,1)
         !
         if (l_elel_corr) Eqp(i2)=Eqp(i2)+Z(i2)*(QP_Vnl_xc(i1)-QP_Vxc(i1))
         !
       enddo
       !
       qp%E(i1)=Eqp(1)
       qp%Z(i1)=Z(1)
       !
     else
       !
       ! COHSEX: no energy dependence
       !
       qp%E(i1)=qp%E_bare(i1)+(QP_Sc(i1,1)+QP_Vnl_xc(i1)-QP_Vxc(i1))
       qp%Z(i1)=1._SP
       !
     endif
     !
   enddo
   !
   SC_corr_now= maxval(real(qp%E(:)-qp%E_bare(:)))
   GWo_SC_done=abs( SC_corr_prev-SC_corr_now )<SC_E_threshold.or.iter==GWo_iterations
   !
 !
 ! Update GWo_iterations
 !
 if (GWo_iterations<0) GWo_iterations=iter
 !
end subroutine
