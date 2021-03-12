
****************************************************************************************************************************/
| PI: 				Cecilia Grant Request 
| Biostatisticans: 	Jessica Janes
| Project: 			Grant Application 
| Data source: 		SEARCH
| Created: 			10/13/2020
****************************************************************************************************************************;

%let date= 02_11_2021;

*MACRO for formating;
%include "S:\Surgery\UrologyResearch\PROJECTS\Predictors National\Data\search format library 2020-01-09.sas";

*********************************************************
****************Using Prospective RP data****************
*********************************************************;

*Import Dataset;
PROC IMPORT OUT= rp
            DATAFILE= "S:\Surgery\UrologyResearch\PROJECTS\RP\Sub-Studies\Human density fibroblast + periprostatic fat project (Cecilia DOD Grant)\Data\ProspectiveRP_DatabaseExport_20200928.csv" 
            DBMS=CSV REPLACE;
RUN;
*Check proper import;
proc contents data=rp;run;
proc print data=rp (obs=25); var Patient_id height weight;run;
data rp;
	set rp;
	if Patient_id="." then delete;
run;

*import patient list (n = 167);
PROC IMPORT OUT= patients
            DATAFILE= "S:\Surgery\UrologyResearch\PROJECTS\RP\Sub-Studies\Human density fibroblast + periprostatic fat project (Cecilia DOD Grant)\Shipments\PPAT Shipment_All Shipments List.csv" 
            DBMS=CSV REPLACE;
RUN;
data patients (keep= Patient_id Notes); 
 set patients;
 run;
*Check proper import;
proc contents data=patients;run;
proc print data=patients (obs=15); var Patient_id; run;

*sort by patient id;
proc sort data=rp; by Patient_id; run;
proc sort data=patients; by Patient_id; run;
*merge datasets;
data data1;
	merge patients (in=a) rp;
	by Patient_id;
	if a;
	run;
proc contents data=data1;run;

*fix missing values;
data data;
 set data1;
 array change _numeric_;
  do over change;
   if change=-999 then change=.;
   else if change=999 then change=.;
  end;
 array change2 _numeric_;
  do over change2;
   if change2=99 then change2=.;
   else if change2=99 then change2=.;
  end;
 array change1 _character_;
  do over change1;
   if change1=-999 then change1="";
   else if change1=999 then change1="";
  end;
 run;

*Calculate BMI;
Data data_bmi;
	set data;
	BMI = (703*Weight)/(height**2);
run;

*pull out relavent vars from prospective RP data & put into working dataset;
data working;
	set data_bmi;
	keep Patient_id BMI Percent_Body_Fat Height psa race Waist Weight rp_path_stage rp_m_stage rp_n_stage;
	run;

*link to rmsid;
PROC import out= rms 
 datafile= "S:\Surgery\UrologyResearch\PROJECTS\RP\Sub-Studies\Human density fibroblast + periprostatic fat project (Cecilia DOD Grant)\Patient Lists\Prospective RP Patient List 2020-12-07.csv" 
 DBMS=csv REPLACE;
RUN;
data rms (keep= Patient_id rmsid); 
 set rms;
 run;
proc sort data=working; by Patient_id; run;
proc sort data=rms; by Patient_id; run;
data working1;
	merge working (in=a) rms;
	by Patient_id;
	if a;
	run;

* read in SEARCH data;
PROC import out= search 
 datafile= "S:\Surgery\UrologyResearch\PROJECTS\Predictors National\Data\VINCI Exports\SEARCH+2021-01-06.dta" 
 DBMS=STATA REPLACE;
RUN;

data search;
	set search;
	rename race=searchrace;
	run;
	proc contents data=search;run;

*compute NCCNriskgroup;
data search1 (drop=flag2);
	set search;
	if (psa< 10 & bxgl<7 and cstg="T1c") then NCCNriskgroup=1; *1=low risk;
	if (psa< 10 & bxgl<7 and cstg="T2a") then NCCNriskgroup=1;
	
	flag2=0;
	if flag2=0 & ((10<=psa<=20) | bxgl=7 | cstg="T2b" |cstg="T2c") then NCCNriskgroup=2; *2=intermediate risk;

	if (10<=psa<=20) & cstg="T2b" then flag2=1; 
	if (10<=psa<=20) & cstg="T2c" then flag2=1;
	if (10<=psa<=20) & bxgl=7 then flag2=1;
	if cstg="T2b" & bxgl=7 then flag2=1;
	if cstg="T2c" & bxgl=7 then flag2=1;

	if  flag2=1 then NCCNriskgroup=3; *3=highrisk;
	if (psa>20 | bxgl ge 8 | cstg="T3") then NCCNriskgroup=3; *3=highrisk;
run;

*pull out relavent search vars;
data temp;
	set search1;
	keep rmsid age chol deadofpc dm FormerSmoker fu limbo mets m n pogl pogl1 pogl2 r r2 race ethnew riskd s stg smoking NCCNriskgroup psa year;
run;

proc sort data=working1; by rmsid; run;
proc sort data=temp; by rmsid; run;
*merge working dataset w relevant vars from search;
data working2;
	merge working1 (in=a) temp;
	by rmsid;
	if a;
	run;
	proc contents data=working2;run;

*get ffq data to create indicator;
PROC import out= ffq 
 datafile= "S:\Surgery\UrologyResearch\PROJECTS\Prospective Biopsy\Data\Food Frequency Questionnaire (FFQ)\Format Data\Formatted Data\FOOD_AND_NUTR_IDS_DII_20200108.csv" 
 DBMS=CSV REPLACE;
RUN;
data ffq1 (keep=Patient_id ffq1_completed RMSID); 
 set ffq;
 ffq1_completed=1;
 rename id=Patient_id;
 run;
*merge ffq data w working data to get ffq_completed indicator;
proc sort data=ffq1; by Patient_id; run;
proc sort data=working2; by Patient_id; run;
data _all_;
	merge working2 (in=a) ffq1;
	by Patient_id;
	if a;
	run;
data _all2_;
	set _all_;
	if ffq1_completed = . then ffq1_completed = 0;
	else ffq1_completed = 1;
	run;
PROC import out= dii
 datafile= "S:\Surgery\UrologyResearch\PROJECTS\Prospective Biopsy\Data\Dietary Inflammatory Index (DII)\duke dii all_1011.csv" 
 DBMS=CSV REPLACE;
RUN; 
proc sort data=_all2_; by Patient_id; run;
proc sort data=dii; by Patient_id; run;
data AllData;
	merge _all2_ (in=a) dii;
	by Patient_id;
	if a;
	run;

*link to genome dx id;
PROC import out= genomedxid
 datafile= "S:\Surgery\UrologyResearch\PROJECTS\Decipher Biosciences (Genome DX)\Keys\GenomeDx to Database IDs.csv" 
 DBMS=CSV REPLACE;
RUN;
data gendxid (keep=rmsid genomedxid); 
set genomedxid; 
run;

*merge;
proc sort data=AllData; by rmsid; run;
proc sort data=gendxid; by rmsid; run;
data CeceliaDataRequest_&date.;
	merge AllData (in=a) gendxid;
	by rmsid;
	if a;
	run;
proc sort data=CeceliaDataRequest_&date. nodupkey; by Patient_id; run;
proc contents data=CeceliaDataRequest_&date.;run;

*delete patients excluded by Michael;
data CeceliaDataRequest_&date.;
	set CeceliaDataRequest_&date.;
	if Patient_id=20274 then delete;
	if Patient_id=20275 then delete;
	if Patient_id=20139 then delete;
	if Patient_id=20216 then delete;
	if Patient_id=20271 then delete;
run;

*export data;
PROC export Data= WORK.CeceliaDataRequest_&date.
            OUTFILE= "S:\Surgery\UrologyResearch\PROJECTS\RP\Sub-Studies\Human density fibroblast + periprostatic fat project (Cecilia DOD Grant)\Data\CeceliaDataRequest&date..csv" 
            DBMS=CSV REPLACE;
RUN;

proc contents data=CeceliaDataRequest_&date.;run;
*deidentify data;
data deidentified1(keep = Height Weight Waist Percent_Body_Fat psa BMI fu year limbo pogl pogl1 pogl2 m n s r dm mets age deadofpc
stg ethnew riskd r2 chol smoking formersmoker NCCNriskgroup ffq1_completed diinormwithoutsupp diinormwithsupp diidenwithoutsupp
diidenwithsupp genomedxid);
	set CeceliaDataRequest_&date.;
	run;

PROC export Data= WORK.deidentified1 
            OUTFILE= "S:\Surgery\UrologyResearch\PROJECTS\RP\Sub-Studies\Human density fibroblast + periprostatic fat project (Cecilia DOD Grant)\Data\CeceliaDataRequest&date._de-identified.csv" 
            DBMS=CSV REPLACE;
RUN;

*****************************
********error checks********;
*****************************

*first check missingness;
data errors1 (keep=rmsid Patient_id error);
 set CeceliaDataRequest_20201122;
 if psa=. then error="missing psa from search";
 if error = "" then delete;
 run;
data errors2 (keep=rmsid Patient_id error);
 set CeceliaDataRequest_20201122;
 if Height=. then error="missing height from RP";
 if error = "" then delete;
 run;
data errors3 (keep=rmsid Patient_id error);
 set CeceliaDataRequest_20201122;
 if Weight=. then error="missing weight from RP";
 if error = "" then delete;
 run;
 data errors4 (keep=rmsid Patient_id error);
 set CeceliaDataRequest_20201122;
 if Waist=. then error="missing waist from RP";
 if error = "" then delete;
 run;
 data errors5 (keep=rmsid Patient_id error);
 set CeceliaDataRequest_20201122;
 if Percent_Body_Fat=. then error="missing percent body fat from RP";
 if error = "" then delete;
 run;
 /*data errors6 (keep=rmsid Patient_id error);
 set CeceliaDataRequest_20201122;
 if SurgicalMargins=. then error="missing surgical margins from RP";
 if error = "" then delete;
 run;
 data errors7 (keep=rmsid Patient_id error);
 set CeceliaDataRequest_20201122;
 if SeminalVesicleInvasion=. then error="missing seminal vesicale invasion from RP";
 if error = "" then delete;
 run;
data errors8 (keep=rmsid Patient_id error);
 set CeceliaDataRequest_20201122;
 if PositiveLymphNodes="." then error="missing positive lyph nodes from RP";
 if error = "" then delete;
 run;*/
data errors9 (keep=rmsid Patient_id error);
 set CeceliaDataRequest_20201122;
 if race=. then error="missing race from RP";
 if error = "" then delete;
 run;

 data errors10 (keep=rmsid Patient_id error);
 set Ceceliadatarequest_02_11_2021;
 if dm=. then error="missing diabetes (dm) from SEARCH";
 if error = "" then delete;
 run;

*now check for odd values;
proc univariate data=CeceliaDataRequest_20201122;
	var bmi;
	histogram;
	INSET N = 'Number patients' MEDIAN (8.2) MEAN (8.2) STD="Standard Deviation" (8.3) MIN = "Minimum BMI" (8.2) MAX ="Maximum BMI" (8.1)/ POSITION = ne;
run;
proc univariate data=CeceliaDataRequest_20201122;
	var psa;
	histogram;
	INSET N = 'Number patients' MEDIAN (8.2) MEAN (8.2) STD="Standard Deviation" (8.3) MIN = "Minimum PSA" (8.2) MAX ="Maximum PSA" (8.1)/ POSITION = ne;
run; 
*note outlier of 108.7, so write error for that;
/*data errors10 (keep=rmsid Patient_id error);
 set CeceliaDataRequest_20201122;
 if psa>100 then error="psa>100 in search";
 if error = "" then delete;
 run;*/
proc univariate data=CeceliaDataRequest_20201122;
	var Height;
	histogram;
	INSET N = 'Number patients' MEDIAN (8.2) MEAN (8.2) STD="Standard Deviation" (8.3) MIN = "Minimum Height" (8.2) MAX ="Maximum Height" (8.1)/ POSITION = ne;
run;
proc univariate data=CeceliaDataRequest_20201122;
	var Weight;
	histogram;
	INSET N = 'Number patients' MEDIAN (8.2) MEAN (8.2) STD="Standard Deviation" (8.3) MIN = "Minimum Weight" (8.2) MAX ="Maximum Weight" (8.1)/ POSITION = ne;
run;
proc univariate data=CeceliaDataRequest_20201122;
	var Waist;
	histogram;
	INSET N = 'Number patients' MEDIAN (8.2) MEAN (8.2) STD="Standard Deviation" (8.3) MIN = "Minimum Wiast" (8.2) MAX ="Maximum Waist" (8.1)/ POSITION = ne;
run; *looks a bit skewed;
proc univariate data=CeceliaDataRequest_20201122;
	var Percent_Body_Fat;
	histogram;
	INSET N = 'Number patients' MEDIAN (8.2) MEAN (8.2) STD="Standard Deviation" (8.3) MIN = "Minimum %bodyfat" (8.2) MAX ="Maximum %bodyfat" (8.1)/ POSITION = ne;
run;


data errors11 (keep=rmsid Patient_id error);
 set CeceliaDataRequest_20201122;
 if rmsid = . then error="no rmsid (patient not in RMS RP crosswalk)";
 if error = "" then delete;
 run;

data errors12 (keep=rmsid Patient_id error);
 set CeceliaDataRequest_20201214;
 if fu = . & year = . & limbo = . then error="patient not found in SEARCH export";
 if error = "" then delete;
 if rmsid = . then delete;
 run;

*merge errors;
data all_errors;
 length Patient_id rmsid 8. error $ 60.;
 set errors1-errors5 errors9 errors11 errors12;
 run;
proc sort data=all_errors;
	by error Patient_id ;
	run;

* export errors;
PROC EXPORT DATA= WORK.all_errors
 OUTFILE= "S:\Surgery\UrologyResearch\PROJECTS\RP\Sub-Studies\Human density fibroblast + periprostatic fat project (Cecilia DOD Grant)\Data\rp errors &date..csv" 
 DBMS=csv REPLACE;
RUN;

PROC EXPORT DATA= WORK.errors12
 OUTFILE= "S:\Surgery\UrologyResearch\PROJECTS\RP\Sub-Studies\Human density fibroblast + periprostatic fat project (Cecilia DOD Grant)\Data\search patients not exporting &date..csv" 
 DBMS=csv REPLACE;
RUN;

PROC EXPORT DATA= WORK.errors10
 OUTFILE= "S:\Surgery\UrologyResearch\PROJECTS\RP\Sub-Studies\Human density fibroblast + periprostatic fat project (Cecilia DOD Grant)\Data\RP_SEARCH_missing_dm &date..csv" 
 DBMS=csv REPLACE;
RUN;
