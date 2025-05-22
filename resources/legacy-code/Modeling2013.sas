© 2024 Institute for Clinical Evaluative Sciences. All rights reserved.

TERMS OF USE:

##Not for distribution.## This code and data is provided to the user solely for its own non-commercial use by individuals and/or not-for-profit corporations. User shall not distribute without express written permission from the Institute for Clinical Evaluative Sciences.

##Not-for-profit.## This code and data may not be used in connection with profit generating activities.

##No liability.## The Institute for Clinical Evaluative Sciences makes no warranty or representation regarding the fitness, quality or reliability of this code and data.

##No Support.## The Institute for Clinical Evaluative Sciences will not provide any technological, educational or informational support in connection with the use of this code and data.

##Warning.## By receiving this code and data, user accepts these terms, and uses the code and data, solely at its own risk.

========================================================================

** Purpose: Model initiation and cessation probabilities by APC model (Holford);

options notes;

proc datasets library=work;
delete all: c:;
run;

proc format;
value ageband 0-9 = '00-09'
		10-19 = '10-19'
		20-29 = '20-29'
		30-39 = '30-39'
		40-49 = '40-49'
		50-59 = '50-59'
		60-69 = '60-69'
		70-79 = '70-79'
		80-89 = '80-89'
		90-high = '90-99'
		;
value newageband 5-14 = '05-14'
		15-24 = '15-24'
		25-34 = '25-34'
		35-44 = '35-44'
		45-54 = '45-54'
		55-64 = '55-64'
		65-74 = '65-74'
		75-84 = '75-84'
		85-high = '85-99'
		;
value newagebandtwo 5-14 = '05-14'
		15-24 = '15-24'
		25-34 = '25-34'
		35-high = '35-99'
		;
value newagebandthree 5-14 = '05-14'
		15-24 = '15-24'
		25-34 = '25-34'
		35-44 = '35-44'
		45-high = '45-99'
		;
value agegroup 5-9='05-09'
		10-14 = '10-14'
		15-19 = '15-19'
		20-24 = '20-24'
		25-29 = '25-29'
		30-34 = '30-34'
		35-39 = '35-39'
		40-44 = '40-44'
		45-49 = '45-49'
		50-54 = '50-54'
		55-59 = '55-59'
		60-64 = '60-54'
		65-high = '65+'
		;
value yrband 1900-1909 = '1900-1939'
			1910-1919 = '1900-1939'
			1920-1929 = '1900-1939'
			1930-1939 = '1900-1939'
			1940-1949 = '1940-1959'
			1950-1959 = '1940-1959'
			1960-1969 = '1960-1979'
			1970-1979 = '1960-1979'
			1980-1989 = '1980-2009'
			1990-1999 = '1980-2009'
			2000-2009 = '1980-2009'
			;
run;

data allsurveys;
set ahrquni.datasets;
run;
proc sort data=allsurveys; by ont_id; run;
data allsurveys_p;
set _null_;
run;

** Macro for initiation by sex;
%macro holford_init(sex=);
data datasets; 
set ahrquni.datasets;
where sex="&sex.";
if agefirst ne .;
if smk_01a=2 or smkc_01a=2 or smkc_01a=2 or smke_01a=2 then do;
agefirst=101;
agestartdaily=101;
agestopdaily=101;
agestop=101;
end;
if agefirst=101 then init=0;
else init=1;
init_date=mdy(month(cchsbdate),day(cchsbdate),year(cchsbdate)+agefirst)+floor(ranuni(6543)*365);
format init_date date9.;
cohort=year(cchsbdate);
if cohort ge 1920;
run;
data inits; /* Numerator for APC rates */
set datasets;
where init=1;
age=agefirst;
if age ge 8;
period=cohort+age;
keep ont_id weighting age cohort period init;
run;
proc sort data=inits; by age period cohort; run;
proc means data=inits sum noprint;
by age period cohort;
weight weighting;
var init;
output out=init_&sex. sum(init)=d;
run;

data _initpop;
set _null_;
run;

data _allprobs_&sex;
set _null_;
run;

%do yy=1928 %to 2013; /* Denominator for APC rates */
data dd;
set ahrquni.datasets;
where sex="&sex.";
if agefirst ne .;
if smk_01a=2 or smkc_01a=2 or smkc_01a=2 or smke_01a=2 then do;
agefirst=101;
agestartdaily=101;
agestopdaily=101;
agestop=101;
end;
cohort=year(cchsbdate);
period=&yy;
age=period-cohort;
if age le agefirst then pop=1;
else pop=0;
if age lt 8 or age gt surveyage then delete;
keep ont_id pop age period cohort weighting;
run;
data _initpop;
set _initpop dd;
run;
%end;
proc sort data=_initpop; by age period; run;
proc means data=_initpop sum noprint;
by age period cohort;
weight weighting;
var pop;
output out=init_pop_&sex. sum(pop)=pop;
run;

data blib.init_&sex;
set init_&sex;
keep age period cohort d;
run;
data blib.init_pop_&sex;
set init_pop_&sex;
keep age period cohort pop;
run;

%do yr=1920 %to 2013; /* Survival probabilities from age to survey by initiation status */
data dp;
set ahrquni.datasets;
where sex="&sex.";
if agefirst ne .;
if smk_01a=2 or smkc_01a=2 or smkc_01a=2 or smke_01a=2 then do;
agefirst=101;
agestartdaily=101;
agestopdaily=101;
agestop=101;
end;
cohort=year(cchsbdate);
period=&yr;
age=period-cohort;
pop=1;
if age ge agefirst then init=1;
else init=0;
if maxyr lt &yr or (sdccfimm=1 and sdcc_3 gt &yr) or (sdcefimm=1 and sdce_3 gt &yr) or (sdcfimm=1 and sdc_3 gt &yr) then do; /* Only include residents of Canada in estimates */
init=.;
pop=.;
end;
if age lt 8 or age gt surveyage then delete;
run;
proc sort data=dp; by ont_id; run;
data prod;
merge ahrquni.allsurveys_prod (in=a) dp (in=b);
by ont_id;
if a and b;
run;
proc sort data=prod; by age period init; run;
proc means data=prod mean noprint;
where pop=1;
by age period init;
weight weighting;
var prod&yr;
output out=prodout mean(prod&yr)=prob;
run;
data prodout; set prodout; where _freq_ ge 30; run; /* Stabilize the estimates */
proc transpose data=prodout out=prodt prefix=init;
by age period;
id init;
var prob;
run;

data _allprobs_&sex;
set _allprobs_&sex prodt;
run;
%end;
run;
%mend;
%holford_init(sex=M);
%holford_init(sex=F);
proc sort data=_allprobs_m; by age period; run;
proc sort data=_allprobs_f; by age period; run;

/* Combine numerators and denominators by age period cohort */
data all_m;
merge blib.init_m blib.init_pop_m;
by age period cohort;
if d=. and pop ne . then do;
d=0;
cohort=period-age;
end;
if cohort ge 1920;
per=period;
coh=cohort;
run;
data all_f;
merge blib.init_f blib.init_pop_f;
by age period cohort;
if d=. and pop ne . then do;
d=0;
cohort=period-age;
end;
if cohort ge 1920;
per=period;
coh=cohort;
run;

data oo;
input ikn $ @@;
datalines;
99999999
;
run;
options nomprint nonotes;
%macro predicts;
data _allcombinations;
set _null_;
run;
%do a=8 %to 99;
%do c=1880 %to 2065;
%let p=%eval(&c.+&a.);
data op;
set oo;
age=&a;
period=&p;
per=period;
coh=&c;
cohort=coh;
run;
data _allcombinations;
set _allcombinations op;
run;
%end;
%end;
%mend;
%predicts;

/* Holford macro for genertion of APC estimates */
options mprint notes;
*____________________________________________________________________________;
*
* MACRO to generate the spline basis for a temporal variable in a model.
*____________________________________________________________________________;

%macro spline(name,x_l,x_h,fix_l,fix_h,slp_l, slp_h,knts,in_file,out_file);
*____________________________________________________________________________;
*                                                                            ;
* MACRO for generating constrained natural cubic splines orthogonal to linear;
*     name = name associated with the temporal variable (age, per or coh);
*     x_l = lower limit for the temporal variable;
*     x_h = upper limit for the temporal variable;
*     knts = row vector for the knots;
*     fix_l = lower bound for fixed effect;
*     fix_h = upper bound for fixed effect;
*     in_file = name of input file;
*     out_file = name of output file;
*____________________________________________________________________________;

proc iml;
* Generate matrix of times and knots;
x0 = (&fix_l:&fix_h)`;
x1 = (&slp_l:&slp_h)`;
k = {&knts};
num_x = nrow(x0);
num_s = nrow(x1);
num_knts = ncol(k);
num_spl = num_knts-2;
x = (shape(x0`,num_spl,num_x))`;
xs = (shape(x1`,num_spl,num_s))`;
knots = shape(k[1:num_spl],num_x,num_spl);
knots1 = shape(k[1:num_spl],num_s,num_spl);

* Construct matrix of constrained cubic splines at the specified knots;
z = (x>=knots)#((x-knots)##3)+
((x>k[num_knts])#((x-k[num_knts])##3)#(k[num_knts-1]-knots)-(x>k[num_knts-1])#((x-k[num_knts-1])##3)#(k[num_knts]-knots))/
(k[num_knts]-k[num_knts-1]);
z1 = z[(&slp_l-&fix_l+1):(&slp_h-&fix_l+1),];

* Make constrained cubic splines orthogonol to linear trend;
l = shape(1,num_x,1)||x0;
l1 = l[(&slp_l-&fix_l+1):(&slp_h-&fix_l+1),];
z_star = z - l*inv(l1`*l1)*l1`*z1;

* Standardized time variable;
xs = x0 - (x0[+]/num_x);
indx = 1:num_spl;
spl_names = cat("&name","_spl", indx);
&name._spl = spl_names;
c_name = {"&name" "&name._s"} || spl_names;
out_mat0 = x0 || xs || z_star;
out_mat = shape(0,%EVAL(&x_h-&x_l+1),(num_spl+2));
out_mat[,1] = (&x_l:&x_h)`;
out_mat[(&fix_l-&x_l+1):(&fix_h-&x_l+1),]=out_mat0;
if (&fix_l-&x_l>0) then out_mat[(1:(&fix_l-&x_l)),(2:num_knts)]=
shape(out_mat[(&fix_l-&x_l+1),(2:num_knts)],(&fix_l-&x_l),(num_knts-1));
out_mat[((&fix_h-&x_l+1):(&x_h-&x_l+1)),(2:num_knts)]=
shape(out_mat0[(&fix_h-&fix_l+1),(2:num_knts)],(&x_h-&fix_h+1),(num_knts-1));
create time_spl from out_mat [colname=c_name];  append from out_mat;
quit;
run;

data work1;  set &in_file;
proc sort;  by &name;
run;

data &out_file;  
merge work1 time_spl;  by &name;
run;

%mend spline;

/* Another macro that keeps track of the variable name is handy if you change the number or location of knots:*/

%macro name_spl(nm,number);
      %local n;
      %do n=1 %to (&number-2);
            &nm&n
      %end;
%mend name_spl;
run;


/* You will notice these contain several macros that are essentially ranges and location of knots.  So an example of how I use these in my program for fitting ever smoker prevalence uses: */

* Knots for spline functions of temporal effects;
* EVER--cross section estimate used for calibration:;
%let ec_a_r_l = 8;
%let ec_a_r_u = 99;
%let ec_a_f_l = 8;
%let ec_a_f_u = 99;
%let ec_a_s_l = 8;
%let ec_a_s_u = 99;
%let ec_a_knots = 10 15 20 50 60;  %let ec_a_n = 5;
%let ec_p_r_l = 1888;
%let ec_p_r_u = 2164;
%let ec_p_f_l = 1928;
%let ec_p_f_u = 2013;
%let ec_p_s_l = 1928;
%let ec_p_s_u = 2013;
%let ec_p_knots = 1940 1950 1960 1970 1980; %let ec_p_n = 5;
%let ec_c_r_l = 1880;
%let ec_c_r_u = 2065;
%let ec_c_f_l = 1920;
%let ec_c_f_u = 1985;
%let ec_c_s_l = 1920;
%let ec_c_s_u = 1985;
%let ec_c_knots =  1930 1940 1945 1950 1955 1960 1965 1970 1975 1980; %let ec_c_n = 10;


/*So the analysis uses the following code:*/
proc sort data=all_m; by age period cohort; run;
proc sort data=_allcombinations; by age period cohort; run;
data _somecombinations;
merge _allcombinations (in=a drop=ikn) all_m (in=b keep=age period cohort);
by age period cohort;
if a and not b;
run;
data all_mm;
set all_m _somecombinations;
run;
proc sort data=all_mm; by age per coh; run;

%spline(age,&ec_a_r_l,&ec_a_r_u,&ec_a_f_l,&ec_a_f_u,&ec_a_s_l,&ec_a_s_u,&ec_a_knots,all_mm,ever_ca);
%spline(period,&ec_p_r_l,&ec_p_r_u,&ec_p_f_l,&ec_p_f_u,&ec_p_s_l,&ec_p_s_u,&ec_p_knots,ever_ca,ever_cap);
%spline(cohort,&ec_c_r_l,&ec_c_r_u,&ec_c_f_l,&ec_c_f_u,&ec_c_s_l,&ec_c_s_u,&ec_c_knots,ever_cap,ever_capc);
run;

data ever_capcm1;  set ever_capc;
array age_sp {%eval(&ec_a_n-1)} age_s age_spl1-age_spl%eval(&ec_a_n-2);
array period_sp {%eval(&ec_p_n-1)} period_s period_spl1-period_spl%eval(&ec_p_n-2);
array cohort_sp {%eval(&ec_c_n-1)} cohort_s cohort_spl1-cohort_spl%eval(&ec_c_n-2);

if (period_s=.) then do p = 1 to %eval(&ec_p_n-1);
period_sp[p] = 0;
end;
if (cohort_s=.) then do c = 1 to %eval(&ec_c_n-1);
cohort_sp[c] = 0;
end;
if (age_s=.) then do a = 1 to %eval(&ec_a_n-1);
age_sp[a] = 0;
end;
if age=. then delete;
run;

* Fit spline model to smokers initiation;
ods listing close;

proc genmod data=ever_capcm1;
model d/pop = age_s period_s cohort_s %name_spl(age_spl,&ec_a_n) %name_spl(period_spl,&ec_p_n) %name_spl(cohort_spl,&ec_c_n)
/ d=b obstats;
ods output ParameterEstimates = beta_ever_m;
ods output ObStats = fitted_ever_m;
run;

ods listing;

data beta_ever_m2;
set beta_ever_m;
new_est=put(estimate,20.16);
run;

/* You will notice these contain several macros that are essentially ranges and location of knots.  So an example of how I use these in my program for fitting ever smoker prevalence uses: */

* Knots for spline functions of temporal effects;
* EVER--cross section estimate used for calibration:;
%let ec_a_r_l = 8;
%let ec_a_r_u = 99;
%let ec_a_f_l = 8;
%let ec_a_f_u = 99;
%let ec_a_s_l = 8;
%let ec_a_s_u = 99;
%let ec_a_knots = 10 15 20 50 60;  %let ec_a_n = 5;
%let ec_p_r_l = 1888;
%let ec_p_r_u = 2164;
%let ec_p_f_l = 1928;
%let ec_p_f_u = 2013;
%let ec_p_s_l = 1928;
%let ec_p_s_u = 2013;
%let ec_p_knots = 1940 1950 1960 1970 1980; %let ec_p_n = 5;
%let ec_c_r_l = 1880;
%let ec_c_r_u = 2065;
%let ec_c_f_l = 1920;
%let ec_c_f_u = 1985;
%let ec_c_s_l = 1920;
%let ec_c_s_u = 1985;
%let ec_c_knots =  1930 1940 1945 1950 1955 1960 1965 1970 1975 1980; %let ec_c_n = 10;

proc sort data=all_f; by age period cohort; run;
proc sort data=_allcombinations; by age period cohort; run;
data _somecombinations;
merge _allcombinations (in=a drop=ikn) all_f (in=b keep=age period cohort);
by age period cohort;
if a and not b;
run;
data all_ff;
set all_f _somecombinations;
run;
%spline(age,&ec_a_r_l,&ec_a_r_u,&ec_a_f_l,&ec_a_f_u,&ec_a_s_l,&ec_a_s_u,&ec_a_knots,all_ff,ever_ca);
%spline(period,&ec_p_r_l,&ec_p_r_u,&ec_p_f_l,&ec_p_f_u,&ec_p_s_l,&ec_p_s_u,&ec_p_knots,ever_ca,ever_cap);
%spline(cohort,&ec_c_r_l,&ec_c_r_u,&ec_c_f_l,&ec_c_f_u,&ec_c_s_l,&ec_c_s_u,&ec_c_knots,ever_cap,ever_capc);
run;

data ever_capcf1;  set ever_capc;
array age_sp {%eval(&ec_a_n-1)} age_s age_spl1-age_spl%eval(&ec_a_n-2);
array period_sp {%eval(&ec_p_n-1)} period_s period_spl1-period_spl%eval(&ec_p_n-2);
array cohort_sp {%eval(&ec_c_n-1)} cohort_s cohort_spl1-cohort_spl%eval(&ec_c_n-2);

if (period_s=.) then do p = 1 to %eval(&ec_p_n-1);
period_sp[p] = 0;
end;
if (cohort_s=.) then do c = 1 to %eval(&ec_c_n-1);
cohort_sp[c] = 0;
end;
if (age_s=.) then do a = 1 to %eval(&ec_a_n-1);
age_sp[a] = 0;
end;
run;

* Fit spline model to smokers initiation;
ods listing close;

proc genmod data=ever_capcf1;
model d/pop = age_s period_s cohort_s %name_spl(age_spl,&ec_a_n) %name_spl(period_spl,&ec_p_n) %name_spl(cohort_spl,&ec_c_n)
/ d=b obstats;
ods output ParameterEstimates = beta_ever_f;
ods output ObStats = fitted_ever_f;
run;

ods listing;

proc sort data=ever_capcm1; by age_s period_s cohort_s; run;
proc sort data=fitted_ever_m; by age_s period_s cohort_s; run;
data fitted_init_m;
merge ever_capcm1 (in=g) fitted_ever_m (in=h keep=age_s period_s cohort_s pred);
by age_s period_s cohort_s;
if g and h;
run;
proc sort data=fitted_init_m; by age period; run; 
proc sort data=_allprobs_m; by period age; run;
data am; set _allprobs_m; where init0 ne . and init1 ne .; ratio=init0/init1; cohort=period-age; run;

/* Correction of survival probabilities where missing */
data _allprobs_m;
set _allprobs_m;
if init0 ne . and init1 ne . and init0 lt init1 then init0=init1;
cohort=period-age;
run;
data am1920;
set am;
if cohort=1920;
run;
proc sort data=am; by age period; run;
proc sort data=am out=am_age nodupkey; by age; run;
proc sort data=am; by cohort age; run;
proc sort data=am out=am_coh nodupkey; by cohort; run;
proc sort data=_allprobs_m; by age period; run;
data fim1 fim2 fim3 fim4;
merge fitted_init_m (in=j) _allprobs_m (in=k drop=cohort);
by age period;
if cohort ne .;
if init0 ne . and init1 ne . then output fim1;
else if period gt 2013 then output fim2;
else if cohort lt 1920 then output fim3;
else output fim4;
run;
data fim2; set fim2; init0=1; init1=1; run;
proc sort data=fim3; by age; run;
data fim3 fim5;
merge fim3 (in=j drop=init0 init1) am1920 (in=k keep=age init0 init1);
by age;
if j;
if k then output fim3;
else output fim5;
run;
data fim4; set fim4 fim5; drop init0 init1; run;
proc sql;
create table fim6 as
select a.*, b.age as agenew, b.cohort as cohortnew, b.period as periodnew, b.init0, b.init1
from fim4 as a, am as b
where a.age le b.age and a.cohort le b.cohort and a.period le b.period
order by a.cohort, a.period, b.period, b.age
;
quit;
proc sort data=fim6; by age period cohort periodnew; run;
proc sort data=fim6 out=fim7(drop=agenew cohortnew periodnew) nodupkey; by age period cohort; run;
proc sort data=fim4; by age period; run;
data fim5;
merge fim4 (in=f) fim7 (in=g keep=age period);
by age period;
if f and not g;
init0=1; init1=1;
run;
data fim; set fim1 fim2 fim3 fim7 fim5; run;
data fitted_init_m;
set fim;
adj_pred=(pred/init1)/((pred/init1)+((1-pred)/init0)); /* Peto model */
run;
proc sort data=fitted_init_m; by age period; run;

proc sort data=ever_capcf1; by age_s period_s cohort_s; run;
proc sort data=fitted_ever_f; by age_s period_s cohort_s; run;
data fitted_init_f;
merge ever_capcf1 (in=g) fitted_ever_f (in=h keep=age_s period_s cohort_s pred);
by age_s period_s cohort_s;
if g and h;
run;
proc sort data=fitted_init_f; by age period;
proc sort data=_allprobs_f; by period age; run;
data af; set _allprobs_f; where init0 ne . and init1 ne .; ratio=init0/init1; cohort=period-age; run;

data _allprobs_f;
set _allprobs_f;
if init0 ne . and init1 ne . and init0 lt init1 then init0=init1;
cohort=period-age;
run;
data af1920;
set af;
if cohort=1920;
run;
proc sort data=af; by age period; run;
proc sort data=af out=af_age nodupkey; by age; run;
proc sort data=af; by cohort age; run;
proc sort data=af out=af_coh nodupkey; by cohort; run;
proc sort data=_allprobs_f; by age period; run;
data fif1 fif2 fif3 fif4;
merge fitted_init_f (in=j) _allprobs_f (in=k drop=cohort);
by age period;
if cohort ne .;
if init0 ne . and init1 ne . then output fif1;
else if period gt 2013 then output fif2;
else if cohort lt 1920 then output fif3;
else output fif4;
run;
data fif2; set fif2; init0=1; init1=1; run;
proc sort data=fif3; by age; run;
data fif3 fif5;
merge fif3 (in=j drop=init0 init1) af1920 (in=k keep=age init0 init1);
by age;
if j;
if k then output fif3;
else output fif5;
run;
data fif4; set fif4 fif5; drop init0 init1; run;
proc sql;
create table fif6 as
select a.*, b.age as agenew, b.cohort as cohortnew, b.period as periodnew, b.init0, b.init1
from fif4 as a, af as b
where a.age le b.age and a.cohort le b.cohort and a.period le b.period
order by a.cohort, a.period, b.period, b.age
;
quit;
proc sort data=fif6; by age period cohort periodnew; run;
proc sort data=fif6 out=fif7(drop=agenew cohortnew periodnew) nodupkey; by age period cohort; run;
proc sort data=fif4; by age period; run;
data fif5;
merge fif4 (in=f) fif7 (in=g keep=age period);
by age period;
if f and not g;
init0=1; init1=1;
run;
data fif; set fif1 fif2 fif3 fif7 fif5; run;
data fitted_init_f;
set fif;
adj_pred=(pred/init1)/((pred/init1)+((1-pred)/init0)); /* Peto model */
run;
proc datasets library=work; delete fim: fif:; run;
proc sort data=fitted_init_m; by age period; run;
proc sort data=fitted_init_f; by age period; run;

/* Repeat as above for cessation */
%macro holford_cess(sex=);
data datasets;
set ahrquni.datasets;
where sex="&sex.";
if agefirst ne .;
if smk_01a=2 or smkc_01a=2 or smkc_01a=2 or smke_01a=2 then do;
agefirst=101;
agestartdaily=101;
agestopdaily=101;
agestop=101;
end;
if agefirst lt 101;
if agestop=101 then cess=0;
else cess=1;
cohort=year(cchsbdate);
if cohort ge 1920;
run;
data cess; /* Numerator of APC model */
set datasets;
where cess=1;
age=agestop;
if age ge 15;
period=cohort+age;
keep ont_id weighting age cohort period cess;
run;
proc sort data=cess; by age period cohort; run;
proc means data=cess sum noprint;
by age period cohort;
weight weighting;
var cess;
output out=cess_&sex. sum(cess)=d;
run;

data _cesspop;
set _null_;
run;

data _allprobs_c_&sex;
set _null_;
run;

%do yy=1920 %to 2013;
data dd; /* Denominator for APC model */
set ahrquni.datasets;
where sex="&sex.";
if agefirst ne .;
if smk_01a=2 or smkc_01a=2 or smkc_01a=2 or smke_01a=2 then do;
agefirst=101;
agestartdaily=101;
agestopdaily=101;
agestop=101;
end;
age=%age(agedate=mdy(1,1,&yy.),bdate=(cchsbdate));
period=&yy;
if age ge agefirst and age le agestop then pop=1;
else pop=0;
if age lt 15 or age gt surveyage then delete;
keep ont_id pop age period weighting;
run;
data _cesspop;
set _cesspop dd;
run;
%end;
proc sort data=_cesspop; by age period; run;
proc means data=_cesspop sum noprint;
by age period;
weight weighting;
var pop;
output out=cess_pop_&sex. sum(pop)=pop;
run;

data blib.cess_&sex;
set cess_&sex;
keep age period cohort d;
run;
data blib.cess_pop_&sex;
set cess_pop_&sex;
keep age period pop;
run;

%do yr=1920 %to 2013;
data dp; /* Survival models from cessation to survey date */
set ahrquni.datasets;
where sex="&sex.";
if agefirst ne .;
if smk_01a=2 or smkc_01a=2 or smkc_01a=2 or smke_01a=2 then do;
agefirst=101;
agestartdaily=101;
agestopdaily=101;
agestop=101;
end;
age=%age(agedate=mdy(1,1,&yr.),bdate=(cchsbdate));
period=&yr;
if age ge agefirst then pop=1;
else pop=0;
if age ge agestop then cess=1;
else cess=0;
if maxyr lt &yr or (sdccfimm=1 and sdcc_3 gt &yr) or (sdcefimm=1 and sdce_3 gt &yr) or (sdcfimm=1 and sdc_3 gt &yr) then do;
cess=.;
pop=.;
end;
if age lt 15 or age gt surveyage then delete;
run;
proc sort data=dp; by ont_id; run;
data prod;
merge ahrquni.allsurveys_prod (in=a) dp (in=b);
by ont_id;
if a and b;
run;
proc sort data=prod; by age period cess; run;
proc means data=prod mean noprint;
where pop=1;
by age period cess;
weight weighting;
var prod&yr;
output out=prodout mean(prod&yr)=prob;
run;
data prodout; set prodout; where _freq_ ge 30; run;
proc transpose data=prodout out=prodt prefix=cess;
by age period;
id cess;
var prob;
run;

data _allprobs_c_&sex;
set _allprobs_c_&sex prodt;
run;
%end;
%mend;
%holford_cess(sex=M);
%holford_cess(sex=F);
proc sort data=_allprobs_c_m; by age period; run;
proc sort data=_allprobs_c_f; by age period; run;

data all_c_m;
merge blib.cess_m blib.cess_pop_m;
by age period;
if d=. and pop ne . then do;
d=0;
cohort=period-age;
end;
if cohort ge 1920;
per=period;
coh=cohort;
run;
data all_c_f;
merge blib.cess_f blib.cess_pop_f;
by age period;
if d=. and pop ne . then do;
d=0;
cohort=period-age;
end;
if cohort ge 1920;
per=period;
coh=cohort;
run;
proc sort data=all_c_m; by cohort age; run;
proc sort data=all_c_f; by cohort age; run;

/* Holford models for APC */
* Knots for spline functions of temporal effects;
* EVER--cross section estimate used for calibration:;
%let ec_a_r_l = 15;
%let ec_a_r_u = 99;
%let ec_a_f_l = 15;
%let ec_a_f_u = 99;
%let ec_a_s_l = 15;
%let ec_a_s_u = 99;
%let ec_a_knots = 30 40 50 60;  %let ec_a_n = 4;
%let ec_p_r_l = 1895;
%let ec_p_r_u = 2164;
%let ec_p_f_l = 1935;
%let ec_p_f_u = 2013;
%let ec_p_s_l = 1935;
%let ec_p_s_u = 2013;
%let ec_p_knots = 1940 1950 1960 1970 1980; %let ec_p_n = 5;
%let ec_c_r_l = 1880;
%let ec_c_r_u = 2065;
%let ec_c_f_l = 1920;
%let ec_c_f_u = 1985;
%let ec_c_s_l = 1920;
%let ec_c_s_u = 1985;
%let ec_c_knots =  1940 1950 1960 1970 1980; %let ec_c_n = 5;

proc sort data=all_c_m; by age period cohort; run;
proc sort data=_allcombinations; by age period cohort; run;
data _somecombinations;
merge _allcombinations (in=a drop=ikn) all_c_m (in=b keep=age period cohort);
by age period cohort;
if a and not b;
if age ge 15;
run;
data all_c_mm;
set all_c_m _somecombinations;
run;
%spline(age,&ec_a_r_l,&ec_a_r_u,&ec_a_f_l,&ec_a_f_u,&ec_a_s_l,&ec_a_s_u,&ec_a_knots,all_c_mm,ever_ca);
%spline(period,&ec_p_r_l,&ec_p_r_u,&ec_p_f_l,&ec_p_f_u,&ec_p_s_l,&ec_p_s_u,&ec_p_knots,ever_ca,ever_cap);
%spline(cohort,&ec_c_r_l,&ec_c_r_u,&ec_c_f_l,&ec_c_f_u,&ec_c_s_l,&ec_c_s_u,&ec_c_knots,ever_cap,ever_capc);
run;

data ever_capcmc1;  set ever_capc;
array age_sp {%eval(&ec_a_n-1)} age_s age_spl1-age_spl%eval(&ec_a_n-2);
array period_sp {%eval(&ec_p_n-1)} period_s period_spl1-period_spl%eval(&ec_p_n-2);
array cohort_sp {%eval(&ec_c_n-1)} cohort_s cohort_spl1-cohort_spl%eval(&ec_c_n-2);

if (period_s=.) then do p = 1 to %eval(&ec_p_n-1);
period_sp[p] = 0;
end;
if (cohort_s=.) then do c = 1 to %eval(&ec_c_n-1);
cohort_sp[c] = 0;
end;
if (age_s=.) then do a = 1 to %eval(&ec_a_n-1);
age_sp[a] = 0;
end;
if age=. then delete;
run;

* Fit spline model to smokers cessation;
ods listing close;

proc genmod data=ever_capcmc1;
model d/pop = age_s period_s cohort_s %name_spl(age_spl,&ec_a_n) %name_spl(period_spl,&ec_p_n) %name_spl(cohort_spl,&ec_c_n)
/ d=b obstats;
ods output ParameterEstimates = beta_ever_m_c;
ods output ObStats = fitted_ever_m_c;
run;

ods listing;

* Knots for spline functions of temporal effects;
* EVER--cross section estimate used for calibration:;
%let ec_a_r_l = 15;
%let ec_a_r_u = 99;
%let ec_a_f_l = 15;
%let ec_a_f_u = 99;
%let ec_a_s_l = 15;
%let ec_a_s_u = 99;
%let ec_a_knots = 30 40 50 60;  %let ec_a_n = 4;
%let ec_p_r_l = 1895;
%let ec_p_r_u = 2164;
%let ec_p_f_l = 1935;
%let ec_p_f_u = 2013;
%let ec_p_s_l = 1935;
%let ec_p_s_u = 2013;
%let ec_p_knots = 1940 1950 1960 1970 1980; %let ec_p_n = 5;
%let ec_c_r_l = 1880;
%let ec_c_r_u = 2065;
%let ec_c_f_l = 1920;
%let ec_c_f_u = 1985;
%let ec_c_s_l = 1920;
%let ec_c_s_u = 1985;
%let ec_c_knots =  1940 1950 1960 1970 1980; %let ec_c_n = 5;

proc sort data=all_c_f; by age period cohort; run;
proc sort data=_allcombinations; by age period cohort; run;
data _somecombinations;
merge _allcombinations (in=a drop=ikn) all_c_f (in=b keep=age period cohort);
by age period cohort;
if a and not b;
if age ge 15;
run;
data all_c_ff;
set all_c_f _somecombinations;
run;
%spline(age,&ec_a_r_l,&ec_a_r_u,&ec_a_f_l,&ec_a_f_u,&ec_a_s_l,&ec_a_s_u,&ec_a_knots,all_c_ff,ever_ca);
%spline(period,&ec_p_r_l,&ec_p_r_u,&ec_p_f_l,&ec_p_f_u,&ec_p_s_l,&ec_p_s_u,&ec_p_knots,ever_ca,ever_cap);
%spline(cohort,&ec_c_r_l,&ec_c_r_u,&ec_c_f_l,&ec_c_f_u,&ec_c_s_l,&ec_c_s_u,&ec_c_knots,ever_cap,ever_capc);
run;

data ever_capcfc1;  set ever_capc;
array age_sp {%eval(&ec_a_n-1)} age_s age_spl1-age_spl%eval(&ec_a_n-2);
array period_sp {%eval(&ec_p_n-1)} period_s period_spl1-period_spl%eval(&ec_p_n-2);
array cohort_sp {%eval(&ec_c_n-1)} cohort_s cohort_spl1-cohort_spl%eval(&ec_c_n-2);

if (period_s=.) then do p = 1 to %eval(&ec_p_n-1);
period_sp[p] = 0;
end;
if (cohort_s=.) then do c = 1 to %eval(&ec_c_n-1);
cohort_sp[c] = 0;
end;
if (age_s=.) then do a = 1 to %eval(&ec_a_n-1);
age_sp[a] = 0;
end;
run;

* Fit spline model to smokers cessation;
ods listing close;

proc genmod data=ever_capcfc1;
model d/pop = age_s period_s cohort_s %name_spl(age_spl,&ec_a_n) %name_spl(period_spl,&ec_p_n) %name_spl(cohort_spl,&ec_c_n)
/ d=b obstats;
ods output ParameterEstimates = beta_ever_f_c;
ods output ObStats = fitted_ever_f_c;
run;

ods listing;

/* Survival corrections for missing data */
proc sort data=ever_capcmc1; by age_s period_s cohort_s; run;
proc sort data=fitted_ever_m_c; by age_s period_s cohort_s; run;
data fitted_cess_m;
merge ever_capcmc1 (in=g) fitted_ever_m_c (in=h keep=age_s period_s cohort_s pred);
by age_s period_s cohort_s;
if g and h;
run;
proc sort data=fitted_cess_m; by age period; run; 
proc sort data=_allprobs_c_m; by period age; run;
data am; set _allprobs_c_m; where cess0 ne . and cess1 ne .; ratio=cess0/cess1; cohort=period-age; run;

data _allprobs_c_m;
set _allprobs_c_m;
if cess0 ne . and cess1 ne . and cess0 gt cess1 then cess1=cess0;
cohort=period-age;
run;
data am1920;
set am;
if cohort=1920;
run;
proc sort data=am; by age period; run;
proc sort data=am out=am_age nodupkey; by age; run;
proc sort data=am; by cohort age; run;
proc sort data=am out=am_coh nodupkey; by cohort; run;
proc sort data=_allprobs_c_m; by age period; run;
data fim1 fim2 fim3 fim4;
merge fitted_cess_m (in=j) _allprobs_c_m (in=k drop=cohort);
by age period;
if cohort ne .;
if cess0 ne . and cess1 ne . then output fim1;
else if period gt 2013 then output fim2;
else if cohort lt 1920 then output fim3;
else output fim4;
run;
data fim2; set fim2; cess0=1; cess1=1; run;
proc sort data=fim3; by age; run;
data fim3 fim5;
merge fim3 (in=j drop=cess0 cess1) am1920 (in=k keep=age cess0 cess1);
by age;
if j;
if k then output fim3;
else output fim5;
run;
data fim4; set fim4 fim5; drop cess0 cess1; run;
proc sql;
create table fim6 as
select a.*, b.age as agenew, b.cohort as cohortnew, b.period as periodnew, b.cess0, b.cess1
from fim4 as a, am as b
where a.age le b.age and a.cohort le b.cohort and a.period le b.period
order by a.cohort, a.period, b.period, b.age
;
quit;
proc sort data=fim6; by age period cohort periodnew; run;
proc sort data=fim6 out=fim7(drop=agenew cohortnew periodnew) nodupkey; by age period cohort; run;
proc sort data=fim4; by age period; run;
data fim5;
merge fim4 (in=f) fim7 (in=g keep=age period);
by age period;
if f and not g;
cess0=1; cess1=1;
run;
data fim; set fim1 fim2 fim3 fim7 fim5; run;
data fitted_cess_m;
set fim;
adj_pred=(pred/cess1)/((pred/cess1)+((1-pred)/cess0));
run;
proc sort data=fitted_cess_m; by age period; run;

proc sort data=ever_capcfc1; by age_s period_s cohort_s; run;
proc sort data=fitted_ever_f_c; by age_s period_s cohort_s; run;
data fitted_cess_f;
merge ever_capcfc1 (in=g) fitted_ever_f_c (in=h keep=age_s period_s cohort_s pred);
by age_s period_s cohort_s;
if g and h;
run;
proc sort data=fitted_cess_f; by age period;
proc sort data=_allprobs_c_f; by period age; run;
data af; set _allprobs_c_f; where cess0 ne . and cess1 ne .; ratio=cess0/cess1; cohort=period-age; run;

data _allprobs_c_f;
set _allprobs_c_f;
if cess0 ne . and cess1 ne . and cess0 gt cess1 then cess1=cess0;
cohort=period-age;
run;
data af1920;
set af;
if cohort=1920;
run;
proc sort data=af; by age period; run;
proc sort data=af out=af_age nodupkey; by age; run;
proc sort data=af; by cohort age; run;
proc sort data=af out=af_coh nodupkey; by cohort; run;
proc sort data=_allprobs_c_f; by age period; run;
data fif1 fif2 fif3 fif4;
merge fitted_cess_f (in=j) _allprobs_c_f (in=k drop=cohort);
by age period;
if cohort ne .;
if cess0 ne . and cess1 ne . then output fif1;
else if period gt 2013 then output fif2;
else if cohort lt 1920 then output fif3;
else output fif4;
run;
data fif2; set fif2; cess0=1; cess1=1; run;
proc sort data=fif3; by age; run;
data fif3 fif5;
merge fif3 (in=j drop=cess0 cess1) af1920 (in=k keep=age cess0 cess1);
by age;
if j;
if k then output fif3;
else output fif5;
run;
data fif4; set fif4 fif5; drop cess0 cess1; run;
proc sql;
create table fif6 as
select a.*, b.age as agenew, b.cohort as cohortnew, b.period as periodnew, b.cess0, b.cess1
from fif4 as a, af as b
where a.age le b.age and a.cohort le b.cohort and a.period le b.period
order by a.cohort, a.period, b.period, b.age
;
quit;
proc sort data=fif6; by age period cohort periodnew; run;
proc sort data=fif6 out=fif7(drop=agenew cohortnew periodnew) nodupkey; by age period cohort; run;
proc sort data=fif4; by age period; run;
data fif5;
merge fif4 (in=f) fif7 (in=g keep=age period);
by age period;
if f and not g;
cess0=1; cess1=1;
run;
data fif; set fif1 fif2 fif3 fif7 fif5; run;
data fitted_cess_f;
set fif;
adj_pred=(pred/cess1)/((pred/cess1)+((1-pred)/cess0));
run;
proc datasets library=work; delete fim: fif:; run;
proc sort data=fitted_cess_m; by age period; run;
proc sort data=fitted_cess_f; by age period; run;

data blib.fitted_init_m_2013; set fitted_init_m; run;
data blib.fitted_init_f_2013; set fitted_init_f; run;
data blib.fitted_cess_m_2013; set fitted_cess_m; run;
data blib.fitted_cess_f_2013; set fitted_cess_f; run;
