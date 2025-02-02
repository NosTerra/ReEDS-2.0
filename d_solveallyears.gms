* global needed for this file:
* case : name of case you're running
* niter : current iteration

$setglobal ds %ds%

$ifthen.unix %system.filesys% == UNIX
$setglobal ds /
$endif.unix


$log 'Running intertemporal solve for...'
$log ' case == %case%'
$log ' iteration == %niter%'

*remove any load years
tload(t) = no ;

$if not set niter $setglobal niter 0
$eval previter %niter%-1

*if this isn't the first iteration
$ifthene.notfirstiter %niter%>0

$if not set load_ref_dem $setglobal load_ref_dem 0

$ifthene.loadref %load_ref_dem% == 0
* need to load psupply0 and load_exog0...
* should also set load_exog to load_exog0


$endif.loadref

*============================
* --- CC and Curtailment ---
*============================

*indicate we're loading data
tload(t)$tmodel(t) = yes ;

$gdxin ReEDS_Augur%ds%augur_data%ds%ReEDS_Augur_merged_%niter%.gdx
$loaddcr curt_old_load2 = curt_old
$loaddcr curt_mingen_load2 = curt_mingen
$loaddcr curt_marg_load2 = curt_marg
$loaddcr cc_old_load2 = cc_old
$loaddcr cc_mar_load2 = cc_mar
$loaddcr cc_dr_load2 = cc_dr
$loaddcr sdbin_size_load2 = sdbin_size
$loaddcr curt_stor_load2 = curt_stor
$loaddcr curt_tran_load2 = curt_tran
$loaddcr storage_in_min_load2 = storage_in_min
$loaddcr hourly_arbitrage_value_load2 = hourly_arbitrage_value
$gdxin

curt_old_load(r,h,t) = sum{loadset, curt_old_load2(loadset,r,h,t) } ;
curt_mingen_load(r,h,t) = sum{loadset, curt_mingen_load2(loadset,r,h,t) } ;
curt_marg_load(i,r,h,t) = sum{loadset, curt_marg_load2(loadset,i,r,h,t) } ;

cc_old_load(i,rb,szn,t) = sum{loadset, sum{ccreg$r_ccreg(rb,ccreg), cc_old_load2(loadset,i,rb,ccreg,szn,t) } } ;
cc_mar_load(i,rb,szn,t) = sum{loadset, sum{ccreg$r_ccreg(rb,ccreg), cc_mar_load2(loadset,i,rb,ccreg,szn,t) } } ;

cc_old_load(i,rs,szn,t) = sum{loadset, sum{ccreg$rs_ccreg(rs,ccreg), cc_old_load2(loadset,i,rs,ccreg,szn,t) } } ;
cc_mar_load(i,rs,szn,t) = sum{loadset, sum{ccreg$rs_ccreg(rs,ccreg), cc_mar_load2(loadset,i,rs,ccreg,szn,t) } } ;

cc_dr_load(i,r,szn,t) = sum{loadset, cc_dr_load2(loadset,i,r,szn,t) } ;

sdbin_size_load(ccreg,szn,sdbin,t) = sum{loadset, sdbin_size_load2(loadset,ccreg,szn,sdbin,t) } ;
curt_stor_load(i,v,r,h,src,t) = sum{loadset, curt_stor_load2(loadset,i,v,r,h,src,t) } ;
curt_tran_load(r,rr,h,t) = sum{loadset, curt_tran_load2(loadset,r,rr,h,t) } ;
storage_in_min_load(r,h,t) = sum{loadset, storage_in_min_load2(loadset,r,h,t) } ;
hourly_arbitrage_value_load(i,r,t) = sum{loadset, hourly_arbitrage_value_load2(loadset,i,r,t) } ;

*===========================
* --- Begin Curtailment ---
*===========================

*Clear params before calculation
oldVREgen(r,h,t) = 0 ;
oldMINGEN(r,h,t) = 0 ;
curt_int(i,r,h,t) = 0 ;
curt_totmarg(r,h,t) = 0 ;
curt_excess(r,h,t) = 0 ;
curt_scale(r,h,t) = 0 ;
curt_mingen_int(r,h,t) = 0 ;

oldVREgen(r,h,t)$[tload(t)$rfeas(r)] =
    sum{(i,v,rr)$[cap_agg(r,rr)$vre(i)$valcap(i,v,rr,t)],
          m_cf(i,v,rr,h,t) * CAP.l(i,v,rr,t)
       } ;
oldMINGEN(r,h,t)$[Sw_Mingen$tload(t)$rfeas(r)] = sum{h_szn(h,szn), MINGEN.l(r,szn,t) } ;

*Sw_Int_Curt=0 means use average curtailment, and don't differentiate techs
if(Sw_Int_Curt=0,
    curt_int(i,rr,h,t)$[tload(t)$valcap_irt(i,rr,t)$vre(i)$sum{r$cap_agg(r,rr), oldVREgen(r,h,t) + oldMINGEN(r,h,t) }] =
        sum{r$cap_agg(r,rr), curt_old_load(r,h,t) / (oldVREgen(r,h,t) + oldMINGEN(r,h,t)) } ;
    curt_mingen_int(r,h,t)$[Sw_Mingen$tload(t)$rfeas(r)$(oldVREgen(r,h,t) + oldMINGEN(r,h,t))] =
        curt_old_load(r,h,t) / (oldVREgen(r,h,t) + oldMINGEN(r,h,t)) ;
) ;

*For the remaining options we initially use marginal values for curt_int
if(Sw_Int_Curt=1 or Sw_Int_Curt=2 or Sw_Int_Curt=3,
    curt_int(i,r,h,t)$[tload(t)$vre(i)$valcap_irt(i,r,t)] = curt_marg_load(i,r,h,t) ;
    curt_mingen_int(r,h,t)$[Sw_Mingen$tload(t)$rfeas(r)] = curt_mingen_load(r,h,t) ;
    curt_totmarg(r,h,t)$tload(t) =
        sum{(i,v,rr)$[cap_agg(r,rr)$valcap(i,v,rr,t)$vre(i)],
              m_cf(i,v,rr,h,t) * CAP.l(i,v,rr,t) * curt_int(i,rr,h,t)
           }
        + curt_mingen_int(r,h,t) * oldMINGEN(r,h,t)
    ;
) ;

*Sw_Int_Curt=1 means use average curtailment, but differentiate techs.
*We start with marginal values for curtailment, but then scale these such that
*total curtailment is equal to curt_old. Marginals are just used to differentiate based on technology.
if(Sw_Int_Curt=1,
    curt_scale(r,h,t)$tload(t) = 1 ;
    curt_scale(r,h,t)$curt_totmarg(r,h,t) = curt_old_load(r,h,t) / curt_totmarg(r,h,t) ;
    curt_int(i,rr,h,t)$curt_int(i,rr,h,t) = curt_int(i,rr,h,t) * sum{r$cap_agg(r,rr),curt_scale(r,h,t) } ;
    curt_mingen_int(r,h,t)$curt_mingen_int(r,h,t) = curt_mingen_int(r,h,t) * curt_scale(r,h,t) ;
) ;

*Sw_Int_Curt=2 means use marginal curtailment, but group techs together so that they are not differentiated.
if(Sw_Int_Curt=2,
    curt_int(i,rr,h,t)$[tload(t)$valcap_irt(i,rr,t)$vre(i)$sum{r$cap_agg(r,rr), (oldVREgen(r,h,t) + oldMINGEN(r,h,t)) }] =
        sum{r$cap_agg(r,rr), curt_totmarg(r,h,t) / (oldVREgen(r,h,t) + oldMINGEN(r,h,t)) } ;
    curt_mingen_int(r,h,t)$[Sw_Mingen$tload(t)$rfeas(r)$(oldVREgen(r,h,t) + oldMINGEN(r,h,t))] =
        curt_totmarg(r,h,t) / (oldVREgen(r,h,t) + oldMINGEN(r,h,t)) ;
    curt_excess(r,h,t)$curt_totmarg(r,h,t) = curt_old_load(r,h,t) - curt_totmarg(r,h,t) ;
) ;

*Sw_Int_Curt=3 means use marginal curtailment, but leave techs differentiated
if(Sw_Int_Curt=3,
    curt_excess(r,h,t)$curt_totmarg(r,h,t) = curt_old_load(r,h,t) - curt_totmarg(r,h,t) ;
) ;

curt_int(i,r,h,t)$[curt_int(i,r,h,t) > 1] = 1 ;

*curt_marg, curt_old, curt_mingen, and curt_old are only used in the sequential solve, so ensure they are set to zero
curt_marg(i,r,h,t) = 0 ;
curt_old(r,h,t) = 0 ;
curt_mingen(r,h,t) = 0 ;
curt_old(r,h,t) = 0 ;

*===============================
* --- Begin Capacity Credit ---
*===============================

*Clear params before calculation
cc_int(i,v,r,szn,t) = 0 ;
cc_totmarg(i,r,szn,t) = 0 ;
cc_excess(i,r,szn,t) = 0 ;
cc_scale(i,r,szn,t) = 0 ;
sdbin_size(ccreg,szn,sdbin,t) = 0 ;
curt_stor(i,v,r,h,src,t) = 0 ;
curt_tran(r,rr,h,t) = 0 ;
storage_in_min(r,h,t) = 0 ;
hourly_arbitrage_value(i,r,t) = 0 ;

*Storage duration bin sizes by year
sdbin_size(ccreg,szn,sdbin,t)$tload(t) = sdbin_size_load(ccreg,szn,sdbin,t) ;
curt_stor(i,v,r,h,src,t)$[tload(t)$valcap(i,v,r,t)$storage_standalone(i)] = curt_stor_load(i,v,r,h,src,t) ;
curt_tran(r,rr,h,t)$[tload(t)$rfeas(r)$rfeas(rr)$rb(r)$rb(rr)$(not sameas(r,rr))
                     $sum{(n,nn,trtype)$routes_inv(n,nn,trtype,t), translinkage(r,rr,n,nn,trtype)}
                    ] = curt_tran_load(r,rr,h,t) ;

storage_in_min(r,h,t)$[tload(t)$(sum{(i,v)$storage_standalone(i), valcap(i,v,r,t) })] = storage_in_min_load(r,h,t) ;
* Ensure storage_in_min doesn't exceed max input capacity when input capacity < generation capacity
* and when storage_duration_m < storage_duration. Multiple terms are necessary to allow for alternative
* swich settings and cases when input capacity > generation capacity and/or storage_duration_m > storage_duration
* TODO: Pass plant-specific input capacity and duration to Augur and use there
storage_in_min(r,h,t)$storage_in_min(r,h,t) =
    min(storage_in_min(r,h,t),
* scaling by plant-specific pump capacity and storage duration
        sum{(i,v) , ( (storage_duration_m(i,v,r) / storage_duration(i))$storage_duration(i) + 1$(not storage_duration(i)) )
                    * avail(i,h) * sum{rr$cap_agg(r,rr), storinmaxfrac(i,v,rr) * sum{tt$tprev(t,tt), CAP.l(i,v,rr,tt)} } } ,
* scaling by plant-specific storage duration
        sum{(i,v) , ( (storage_duration_m(i,v,r) / storage_duration(i))$storage_duration(i) + 1$(not storage_duration(i)) )
                    * avail(i,h) * sum{(rr,tt)$[tprev(t,tt)$cap_agg(r,rr)], CAP.l(i,v,rr,tt)} } ,
* scaling by plant-specific pump capacity
        sum{(i,v) , avail(i,h) * sum{rr$cap_agg(r,rr), storinmaxfrac(i,v,rr) * sum{tt$tprev(t,tt), CAP.l(i,v,rr,tt)} } }
    ) ;
hourly_arbitrage_value(i,r,t)$[tload(t)$valcap_irt(i,r,t)$storage_standalone(i)] = hourly_arbitrage_value_load(i,r,t) ;
*PV+Battery arbitrage value can be restricted by the ITC charging requirement
hourly_arbitrage_value(i,r,t)$[tload(t)$valcap_irt(i,r,t)$pvb(i)] = hourly_arbitrage_value_load("battery_%GSw_pvb_dur%",r,t) * (1 - pvb_itc_qual_frac) ;

*Upgrades - used for hydropower upgraded to add pumping
curt_stor(i,v,r,h,src,t)$[tload(t)$upgrade(i)$storage_standalone(i)$valcap(i,v,r,t)] = smax(vv, sum{ii$upgrade_to(i,ii), curt_stor(ii,vv,r,h,src,t) } );
hourly_arbitrage_value(i,r,t)$[tload(t)$upgrade(i)$(storage_standalone(i) or hyd_add_pump(i))$valcap_irt(i,r,t)] = sum{ii$upgrade_to(i,ii), hourly_arbitrage_value(ii,r,t) } ;

*Sw_Int_CC=0 means use average capacity credit for each tech, and don't differentiate vintages
*If there is no existing capacity to calculate average, use marginal capacity credit instead.
if(Sw_Int_CC=0,
    cc_int(i,v,r,szn,t)$[tload(t)$vre(i)$valcap(i,v,r,t)$sum{(vv)$(valcap(i,vv,r,t)), CAP.l(i,vv,r,t) }] =
        cc_old_load(i,r,szn,t) / sum{(vv)$(valcap(i,vv,r,t)), CAP.l(i,vv,r,t) } ;
    cc_int(i,v,r,szn,t)$[tload(t)$vre(i)$valcap(i,v,r,t)$(cc_old_load(i,r,szn,t)=0)] = m_cc_mar(i,r,szn,t) ;
) ;

*For the remaining options we initially use marginal values for cc_int, differentiated by vintage based on seasonal capacity factors.
if(Sw_Int_CC=1 or Sw_Int_CC=2,
    cc_int(i,v,r,szn,t)$[tload(t)$vre(i)$valcap(i,v,r,t)$sum{vv$ivt(i,vv,t), m_cf_szn(i,vv,r,szn,t) }] =
        m_cc_mar(i,r,szn,t) * m_cf_szn(i,v,r,szn,t) / sum{vv$ivt(i,vv,t), m_cf_szn(i,vv,r,szn,t) } ;
    cc_totmarg(i,r,szn,t)$[tload(t)$vre(i)] = sum{v$valcap(i,v,r,t), cc_int(i,v,r,szn,t) * CAP.l(i,v,r,t) } ;
) ;

*Sw_Int_CC=1 means use average capacity credit for each tech, but differentiate based on vintage.
*Start with marginal capacity credit with seasonal vintage-based capacity factor adjustment,
*and scale with cc_old_load to result in the correct total capacity credit.
if(Sw_Int_CC=1,
    cc_scale(i,r,szn,t)$[tload(t)$vre(i)] = 1 ;
    cc_scale(i,r,szn,t)$[tload(t)$vre(i)$cc_totmarg(i,r,szn,t)] = cc_old_load(i,r,szn,t) / cc_totmarg(i,r,szn,t) ;
    cc_int(i,v,r,szn,t)$[tload(t)$vre(i)$valcap(i,v,r,t)] = cc_int(i,v,r,szn,t) * cc_scale(i,r,szn,t) ;
) ;

*Sw_Int_CC=2 means use marginal capacity credit, adjusted by seasonal capacity factors by vintage
if(Sw_Int_CC=2,
    cc_excess(i,r,szn,t)$[tload(t)$cc_totmarg(i,r,szn,t)] = cc_old_load(i,r,szn,t) - cc_totmarg(i,r,szn,t) ;
) ;


*no longer want m_cc_mar since it should not enter the planning reserve margin constraint
m_cc_mar(i,r,szn,t) = 0 ;

cc_int(i,v,r,szn,t)$[cc_int(i,v,r,szn,t) > 1] = 1 ;
cc_int(i,v,r,szn,t)$[tload(t)$csp_storage(i)$valcap(i,v,r,t)] = 1 ;

*=======================================
* --- Begin Averaging of CC/Curt ---
*=======================================

$ifthene.afterseconditer %niter%>1

*when set to 1 - it will take the average over all previous iterations
if(Sw_AVG_iter=1,
        cc_int(i,v,r,szn,t)$[tload(t)$vre(i)$valcap(i,v,r,t)] =
          (cc_int(i,v,r,szn,t) + cc_iter(i,v,r,szn,t,"%previter%")) / 2 ;

        curt_int(i,r,h,t)$[tload(t)$vre(i)$valcap_irt(i,r,t)] =
          (curt_int(i,r,h,t) + curt_iter(i,r,h,t,"%previter%")) / 2 ;

        curt_mingen_int(r,h,t)$[Sw_Mingen$tload(t)$rfeas(r)] =
          (curt_mingen_int(r,h,t) + curt_mingen_iter(r,h,t,"%previter%")) / 2 ;
    ) ;

$endif.afterseconditer

*Remove very small numbers to make it easier for the solver
cc_int(i,v,r,szn,t)$[cc_int(i,v,r,szn,t) < 0.001] = 0 ;
curt_int(i,r,h,t)$[curt_int(i,r,h,t) < 0.001] = 0 ;

cc_iter(i,v,r,szn,t,"%niter%")$cc_int(i,v,r,szn,t) = cc_int(i,v,r,szn,t) ;
curt_iter(i,r,h,t,"%niter%")$curt_int(i,r,h,t) = curt_int(i,r,h,t) ;
curt_mingen_iter(r,h,t,"%niter%")$curt_mingen_int(r,h,t) = curt_mingen_int(r,h,t) ;

execute_unload 'ReEDS_Augur%ds%augur_data%ds%curtout_%case%_%niter%.gdx' cc_int, curt_int, oldVREgen ;

*following line will load in the level values if the switch is enabled
*note that this is still within the conditional that we are now past the first iteration
*and thus a loadpoint is enabled
if(Sw_Loadpoint = 1,
execute_loadpoint 'gdxfiles%ds%%case%_load.gdx' ;
ReEDSmodel.optfile = 8 ;
) ;

$endif.notfirstiter


* rounding of all cc and curt parameters
* used in the intertemporal case

cc_int(i,v,r,szn,t) = round(cc_int(i,v,r,szn,t), 4) ;
cc_totmarg(i,r,szn,t) = round(cc_totmarg(i,r,szn,t), 4) ;
cc_excess(i,r,szn,t) = round(cc_excess(i,r,szn,t), 4) ;
cc_scale(i,r,szn,t) = round(cc_scale(i,r,szn,t), 4) ;
curt_int(i,r,h,t) = round(curt_int(i,r,h,t), 4) ;
curt_totmarg(r,h,t) = round(curt_totmarg(r,h,t), 4) ;
curt_excess(r,h,t) = round(curt_excess(r,h,t), 4) ;
curt_scale(r,h,t) = round(curt_scale(r,h,t), 4) ;
curt_mingen_int(r,h,t) = round(curt_mingen_int(r,h,t), 4) ;


*==============================
* --- Solve Supply Side ---
*==============================

solve ReEDSmodel using lp minimizing z ;

if(Sw_Loadpoint = 1,
execute_unload 'gdxfiles%ds%%case%_load.gdx' ;
) ;

*============================
* --- Iteration Tracking ---
*============================

cap_iter(i,v,r,t,"%niter%")$valcap(i,v,r,t) = CAP.l(i,v,r,t) ;
gen_iter(i,v,r,t,"%niter%")$valcap(i,v,r,t) = sum{h, GEN.l(i,v,r,h,t) * hours(h) } ;
gen_iter(i,v,r,t,"%niter%")$[vre(i)$valcap(i,v,r,t)] = sum{h, m_cf(i,v,r,h,t) * CAP.l(i,v,r,t) * hours(h) } ;
cap_firm_iter(i,v,r,szn,t,"%niter%")$cc_int(i,v,r,szn,t) = cc_int(i,v,r,szn,t) * CAP.l(i,v,r,t) ;
cap_firm_iter(i,v,r,szn,t,"%niter%")$storage(i) = sum{sdbin, CAP_SDBIN.l(i,v,r,szn,sdbin,t) * cc_storage(i,sdbin) } ;
curt_tot_iter(i,v,r,t,"%niter%")$[tload(t)$vre(i)$valcap(i,v,r,t)] = sum{h, m_cf(i,v,r,h,t) * CAP.l(i,v,r,t) * curt_int(i,r,h,t) * hours(h) } ;
$ifthene.postseconditer %niter%>1
cc_change(i,v,r,szn,t)$[tload(t)$(vre(i) or storage(i))$valcap(i,v,r,t)] = cc_iter(i,v,r,szn,t,"%niter%") - cc_iter(i,v,r,szn,t,"%previter%") ;
curt_change(i,r,h,t)$[tload(t)$vre(i)$valcap_irt(i,r,t)] = curt_iter(i,r,h,t,"%niter%") - curt_iter(i,r,h,t,"%previter%") ;
curt_mingen_change(r,h,t)$[Sw_Mingen$tload(t)$rfeas(r)] = curt_mingen_iter(r,h,t,"%niter%") - curt_mingen_iter(r,h,t,"%previter%") ;
$endif.postseconditer

*=====================
* --- Demand Side ---
*=====================

*default globals for demand side
$if not set output_lvl $setglobal output_lvl 'use'
$if not set ncores $setglobal ncores 12
$if not set conv_stat $setglobal conv_stat 0
$if not set ref_price $setglobal ref_price 'reeds'

$ifthene.demrun %demand% == 1
*recompute price as the real weighted-average of the marignal off the
*supply-demand balance constraint plus retail adders
  psupply(sec,r,t,h)$[tmodel(t)$rfeas(r)$pvf_onm(t)] = dmd_conv(sec) * (
                        retail_adder(r,sec) +
                        (sum{hh, hours(hh) * load_exog(r,hh,t) * eq_loadcon.m(r,hh,t) } / sum{hh,hours(hh)*load_exog(r,hh,t)}) / pvf_onm(t)
                        ) ;

*supply price for years that aren't solved still need to be passed over to the demand side
*therefore, we linearly interpolate those values between solved years
  psupply(sec,r,t,h)$[(yeart(t)<smax{tt$tmodel(tt), yeart(tt) })$(not tmodel(t))$rfeas(r)
                     $(sum{tt$t_after(t,tt), tt.val } -  sum{tt$t_before(t,tt), tt.val })] =
*the price from the year before
                      sum{tt$t_before(t,tt) ,psupply(sec,r,tt,h) } +
*the amount of years from the unmodeled year to the previously modeled year
                      (yeart(t) - sum{tt$t_before(t,tt), tt.val })  *
*the price difference from t_after and t_before
                      (sum{tt$t_after(t,tt), psupply(sec,r,tt,h) } - sum{tt$t_before(t,tt), psupply(sec,r,tt,h) }) /
*the number of years that have surpassed between modeled years
                      (sum{tt$t_after(t,tt), tt.val } -  sum{tt$t_before(t,tt), tt.val }) ;

*price for years beyond those modeled is assumed to be the last modeled year
  psupply(sec,r,t,h)$[(yeart(t)>smax{tt$tmodel(tt), yeart(tt) })$rfeas(r)] = sum{tt$tlast(tt), psupply(sec,r,tt,h) } ;

*record the prices coming out the supply model as the "actual prices"
  rep(sec,r,t,h,"%niter%","actual_price")$[tmodel(t)$rfeas(r)$pvf_onm(t)] = psupply(sec,r,t,h) ;

  repannual(t,"%niter%","actual_price")$tmodel(t) = sum{(r,h),load_exog(r,h,t)*psupply("res",r,t,h)}
                                                    / sum{(r,h),load_exog(r,h,t)} ;

*if this is the first iteration, set price equal to that coming out of the supply side's reference solve
$ifthene.demfirstiter %niter% == 0
    psupply0(sec,r,t,h)$[tmodel(t)$rfeas(r)$pvf_onm(t)] = psupply(sec,r,t,h) ;
    rep(sec,r,t,h,"%niter%","iterated_price")$[tmodel(t)$rfeas(r)$pvf_onm(t)] = psupply(sec,r,t,h) ;
$endif.demfirstiter

*convergence "algorithm" - just averaging price from one iteration to another
$ifthene.demitercheck %niter%>0

*average price over all last two iterations
    psupply(sec,r,t,h)$rfeas(r) =
        (rep(sec,r,t,h,"%previter%","actual_price")+rep(sec,r,t,h,"%niter%","actual_price")) / 2 ;

$endif.demitercheck

*record the iterated price following these adjustments to the price calculation
*i.e. we want to record the price coming out of the model as actual_price
*and the price going into the demand side as iterated_price
  rep(sec,r,t,h,"%niter%","iterated_price")$[tmodel(t)$rfeas(r)$pvf_onm(t)] = psupply(sec,r,t,h) ;

  repannual(t,"%niter%","iterated_price")$tmodel(t) = sum{(r,h), load_exog(r,h,t) * psupply("res",r,t,h) }
                                                      / sum{(r,h), load_exog(r,h,t) } ;
*output the gdx file needed for the demand-side R script
  Execute_Unload "temp_dmd%ds%price_iter_%case%_%niter%.gdx", psupply, psupply0, rfeas ;


*cur.dir = Args[1]
*ncores = as.integer(Args[2])
*conv.stat = Args[3]
*firstrun= Args[4]
*ref.price = Args[5]
*output.lvl = Args[6]
*case_iteration = Args[7]
*gams system directory = Args[8]

* Execute the demand-side model in R
  Execute 'Rscript %gams.curdir%%ds%demand%ds%dmd_iter.R %gams.curdir% %ncores% %conv_stat% 1 %ref_price% %output_lvl% %case%_%niter% %gams.sysdir%'

*load in demand-side results
  Execute_Load "%gams.curdir%%ds%temp_dmd%ds%dmd_iter_%output_lvl%_%ref_price%_%case%_%niter%.gdx", ResDmdNew = ResDmdNew ;

* Calculate consumption from base stock devices
  ResDmdBase(r,t,h)$[rfeas(r)$tmodel(t)] = sum{(y,u,d,obase)$use2dev2opt(u,d,obase), (ref_serv_dmd_device(y,r,t,h,u,d) *
    ((psupply('res',r,t,h) / lambda(r,'2010',u,d,obase)) / (psupply0('res',r,t,h) / ref_eff(y,r,t,u,d)))**(-res_elas(y,u))) / lambda(r,'2010',u,d,obase) * base_stock(y,r,t,u,d,obase) } ;

* Compute aggregate sectoral consumption
* We are able to use the same conversion as price as we 'double-flip' from mmBTU to MWh
* therefore, can still use the dmd_conv as a multiplier in the following conversions
  DmdSec('res',r,t,h)$[tmodel(t)$rfeas(r)] = dmd_conv('res') * (sum{u,ResDmdNew(r,t,h,u)} + ResDmdBase(r,t,h)) ;
  DmdSec('com',r,t,h)$[tmodel(t)$rfeas(r)] = dmd_conv('com') * ((ref_com_cons(r,t,h) * (psupply('com',r,t,h)/psupply0('com',r,t,h))**(-com_elas))$dflex(t) + ref_com_cons(r,t,h)$[not dflex(t)]) ;
  DmdSec('ind',r,t,h)$[tmodel(t)$rfeas(r)] = dmd_conv('ind') * ((ref_ind_cons(r,t,h) * (psupply('ind',r,t,h)/psupply0('ind',r,t,h))**(-ind_elas))$dflex(t) + ref_ind_cons(r,t,h)$[not dflex(t)]) ;

  DmdSec(sec,r,t,h)$[rfeas(r)$tmodel(t)] = DmdSec(sec,r,t,h) / hours(h) ;
*pre-demand load vs post-demand load (computed below)
  rep(sec,r,t,h,"%niter%","sec_load")$[tmodel(t)$rfeas(r)] = dmdsec(sec,r,t,h) * hours(h) ;
  rep(sec,r,t,h,"%niter%","load_predem")$[tmodel(t)$rfeas(r)] = load_exog(r,h,t) * hours(h) ;

  repannual(t,"%niter%","load_predem")$tmodel(t) = sum{(sec,r,h), rep(sec,r,t,h,"%niter%","load_predem")} ;

*re-compute load_exog
*20180225 MB - no longer adjusting the first period's demand due to infeasibilities
  load_exog(r,h,t)$[(not tfirst(t))$tmodel(t)$rfeas(r)$pvf_onm(t)] = sum{sec, DmdSec(sec,r,t,h) } ;
  peakdem(r,szn,t) = peakdem_h17_ratio(r,szn,t) * load_exog(r,"h17",t) ;

  rep(sec,r,t,h,"%niter%","load_postdem")$[tmodel(t)$rfeas(r)] = load_exog(r,h,t) * hours(h) ;
  repannual(t,"%niter%","load_postdem")$tmodel(t) = sum{(sec,r,h),rep(sec,r,t,h,"%niter%","load_postdem")} ;

  execute_unload 'gdxfiles%ds%demand_%case%_%niter%.gdx' load_exog, load_exog0, psupply, psupply0, rep ;

$endif.demrun
