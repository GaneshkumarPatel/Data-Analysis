/* 1. Import data into SAS environment*/

FILENAME REFFILE '/home/u46528150/Comcast_telecom_complaints_data.csv';

PROC IMPORT DATAFILE=REFFILE
	DBMS=CSV
	OUT=WORK.comcastcomp
	replace;
	GETNAMES=YES;
	options validvarname=v7;
RUN;
PROC CONTENTS DATA=comcast; RUN;

/* 2. Provide the trend chart for the number of complaints at monthly and daily granularity levels.*/

proc sql;
create table daily_complaint As
select Date, count(Ticket__) As complaints from comcastcomp
group by Date order by complaints;
run;

proc sort data=daily_complaint;
by date;
run; 

proc timeseries data=daily_complaint
				plots=series
				out=plot_daily_complaints;
				id Date interval=day accumulate=total;
				var complaints;
run;
proc timeseries data=daily_complaint
				plots=series
				out=plot_daily_complaints;
				id Date interval=month accumulate=total;
				var complaints;
run;				

/* 3. Provide a table with the frequency of complaint types.
       Which complaint types are maximum i.e., around internet, network issues, or acrossany other domain*/

data comp_types;
set comcastcomp;
if Index(upcase(Customer_Complaint) ,'INTERNET') then category='Internet';
else if Index(upcase(Customer_Complaint) ,'BILLING') then category='Billing';
else if Index(upcase(Customer_Complaint) ,'BANDWIDTH') then category='Network';
else if Index(upcase(Customer_Complaint) ,'SERVICE') then category='Service';
else category ='Others';
run;

proc sql;
create table types as
select category, count(category) as comp_typ from comp_types
group by category order by comp_typ desc;

PROC SGPLOT DATA = types;
VBAR category / RESPONSE = comp_typ;
TITLE 'Total complaint count each type';
RUN;

/*4. Create a new categorical variable with value as Open and Closed. Open & Pending is to be categorized
 as Open and Closed & Solved is to be categorized as Closed*/

data open_closed;
set comcastcomp;
if Status='pending' then status_type='Open';
else if Status='Closed' then status_type='Closed';
else if Status='Solved' then status_type='Closed';
else status_type='Open';
run;


/* 5. Provide state wise status of complaints in a stacked bar chart.
     a.    Which state has the maximum complaints*/

proc sql;
create table Open_close as
select status_type, count(status_type) as op_cl_comp from open_closed
group by status_type  order by op_cl_comp desc;

PROC SGPLOT DATA = Open_close;
VBAR status_type / RESPONSE = op_cl_comp;
TITLE 'Total OPEN and Closed complaints';
RUN;


PROC SGPLOT DATA = open_closed;
VBAR State / GROUP = status_type ;
TITLE 'Statewise complaints with status';
run;


data oc;
set comcastcomp;
if Status='pending' then status_type=1;
else if Status='Closed' then status_type=0;
else if Status='Solved' then status_type=0;
else status_type=1;
run;

/* b. Which state has the highest percentage of unresolved complaints*/

PROC SQL;
         CREATE TABLE high_perc_comp_state AS
         SELECT state, sum (status_type)/count(status)*100 as percent_unresolve     
         FROM oc
         group by state order by percent_unresolve dec;

QUIT;


PROC SGPLOT DATA = high_perc_comp_state;
VBAR state / RESPONSE = percent_unresolve;
TITLE 'Total percentage complaints unresolved';
RUN;

/* 6. Provide the percentage of complaints resolved till date, which were received through the
Internet and customer care calls.*/

PROC SQL;
         CREATE TABLE perc_resolved_received_via AS
         SELECT Received_Via, (count(status)-sum (status_type))/count(status)*100 as percent_resolv     
         FROM oc
         group by Received_Via order by percent_resolv dec;

QUIT;


PROC SGPLOT DATA = perc_resolved_received_via;
VBAR Received_Via / RESPONSE = percent_resolv;
TITLE 'Total percentage complaints resolved received_via';
RUN;
