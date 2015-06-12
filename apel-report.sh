#!/bin/bash

loc=$(dirname "$0")

logdir=/var/log
pubdir=/net/nas01/Public

# test run; log under current dir
if [[ $1 = -t ]]; then
  shift
  logdir=.
  pubdir=.
  mkdir -p tmp send
fi

_mlog () {
    echo "$@" >>$logdir/multicore.log
}

mlog () {
    now=`date`
    _mlog "$now :" "$@"
}

get_tmp_rg_name_by_rname () {
    tmp=`mysql -u root oim -s <<< "
      select b.name
        from resource a
           , resource_group b
       where a.name = '$1'
         and a.resource_group_id = b.id ;"`
}

get_tmp_rg_name_by_fqdn () {
    tmp=`mysql -u root oim -s <<< "
      select b.name
        from resource a
           , resource_group b
       where a.fqdn = '$1'
         and a.resource_group_id = b.id ;"`
}

get_tmp_rg_name_by_table () {
   tmp=`grep $1 $loc/RGMap | awk '{ print $2 }'`
   size=${#tmp}
   if [ "$size" -gt "$nlimit" ] ; then
       rg=$tmp
   else
##         lookup failed, default resource group to resource name
       rg=$1
       mlog "resource $1 defaulted to resource group"
   fi
}

res_rg () {
    nlimit=2
    rg="NULL"
    get_tmp_rg_name_by_rname "$@"
    size=${#tmp}
    if [ "$size" -gt "$nlimit" ] ; then
        rg=$tmp
    else
##  proper use of names has failed, try using FQDN rather than name
        get_tmp_rg_name_by_fqdn "$@"
        size=${#tmp}
        if [ "$size" -gt "$nlimit" ] ; then
            rg=$tmp
        else
##     no luck yet, try lookup table
           get_tmp_rg_name_by_table "$@"
        fi
    fi
    echo $rg
}

date_init () {
## send a report for last month for the first 3 days of this month
## this allow last month to finalize and data to be generated for this month
    day=`date +%d`
    if [[ $1 = 20[0-9][0-9] && $2 = [0-9][0-9] ]]; then
        year=$1
        month=$2
        handle="core_final"
    elif [ "$day" -lt "03" ]; then
        year=`date --date="last-month" +%Y`
        month=`date --date="last-month" +%m`
        handle="core_final"
    else
        year=`date --date="yesterday" +%Y`
        month=`date --date="yesterday" +%m`
        handle="core"
    fi
}

param_init () {
## for small core count, node count is 1
    nodes=1

## if there was no data newer that "cutoff" days, there is a problem, log it.
    cutoff=2.00

## cutoff, a username shorter than this is ignored
    limit=5
    limit=-10

## cutoff, stop looking for new users when null result count exceeds this
    nlimit=2

    nmax=200
    zero=0
}

log_init () {
    rm -f $pubdir/tmp/problems_${month}_$year
}

print_report_record () {
    mlog "Writing output of $vo $unique_rg"
## output use summation here
    echo "Site: $unique_rg"
    echo "VO: $vo"
    echo "EarliestEndTime: $min_d"
    echo "LatestEndTime: $max_d"
    echo "Month: $month"
    echo "Year: $year"
    echo "Infrastructure: Gratia-OSG"
    echo "GlobalUserName: $user"
    echo "Processors: $cores"
    echo "NodeCount: $nodes"
## this operation converts the floating point result to integer
    x=`echo "scale=0; $wall/1." | bc`
    echo -n "WallDuration: "
    echo $x
    x=`echo "scale=0; $cpu/1." | bc`
    echo -n "CpuDuration: "
    echo $x
    x=`echo "scale=0; $nwall/1." | bc`
    echo -n "NormalisedWallDuration: "
    echo $x
    x=`echo "scale=0; $ncpu/1." | bc`
    echo -n "NormalisedCpuDuration: "
    echo $x
    echo -n "NumberOfJobs: "
    echo $kjobs
    echo "%%"
}

test_recent_reporting () {
## test for recent reporting
    {
    now=`date +%s`
    age=`echo "$now - $max_d" | bc`
    x=`echo "scale=3; $age/86400." | bc`
    if [ $(echo " $x > $cutoff " | bc) -eq 1 ] ; then
        echo "$unique_rg reported $x days ago, problem"
    fi
    }>>$pubdir/tmp/problems_${month}_$year
}

do_unique_rg () {
## initialize use summations here
   wall=0
   cpu=0
   nwall=0
   ncpu=0
   kjobs=0
   mjobs=0
   min_d=`date +%s`
   max_d=0
   for resource in $resources ; do
       do_resource
   done
   if [ -z "$kjobs" ]; then
       kjobs=0
   fi
   if [ "$kjobs" -ne "$zero" ]; then
      print_report_record
      test_recent_reporting
   fi
}

get_nftest () {
## attempt to get a normalization factor from oim
   nftest=`mysql -u root oim -s <<< "
     select b.apel_normal_factor
       from resource a
          , resource_wlcg b
      where b.resource_id = a.id
        and a.name = '$resource';"`
}

get_nf_tabular () {
## get the default normalization factor for this resource group
   nf=`grep ${rg} $loc/normal_hepspec | awk '{print $2}'`
   if [ "$?" -ne "$zero" ] ; then
       nf=12
       mlog "Warning: Using global default normalization factor $nf for $resource"
   else
       mlog "Warning: Using tabular default normalization factor $nf for $resource"
   fi
}

get_nf () {
## Normalization factor
   get_nftest  ## attempt to get a normalization factor from oim
   if [ -z "$nftest" ] ; then
       nftest=12
       mlog "Warning: Using tabular default normalization factor $nf for $resource"
   fi
## sanity checks on the normalization factor
   if [ $(echo " $nftest < $nmax && $nftest > $zero" | bc) -eq 1 ] ; then
       nf=$nftest
   else
       get_nf_tabular  ## get the default normalization factor for this resource group
   fi
## if all else has failed...
   if [ -z "$nf" ] ; then
       nf=12
       mlog "Warning: Using global default normalization factor $nf for $resource"
   fi
}

get_results () {
## get summed CPU and Wall time for this user on this resource
   mlog "Getting results"

### (ApplicationExitCode=0 and

   results=`echo "use gratia ;
     select sum(m.WallDuration)
          , sum(m.CpuUserDuration)
          , sum(m.njobs)
          , sum(m.CpuSystemDuration)
       from MasterSummaryData m
          , VONameCorrection v
          , Site s
          , Probe p
      where m.VOcorrid = v.corrid
        and s.siteid = p.siteid
        and p.probename = m.ProbeName
        and s.SiteName = '$resource'
        and v.ReportableVOName = '$vo'
        and m.Cores=$cores
        and m.EndTime >= '$year-$month-01'
        and m.EndTime <  '$year-$month-01' + INTERVAL 1 MONTH
        and m.DistinguishedName = '$user_esc' ;
   " | mysql --defaults-extra-file=$loc/qqq | tail -n +2`
}

get_times () {
## find the max and min job end times for the jobs defining usage.
## This is per request from APEL and is different that John W report
   mlog "Getting times $resource"
   times=`echo "use gratia ;
     select min(EndTime)
          , max(EndTime)
       from MasterSummaryData m
          , VONameCorrection v
          , Site s
          , Probe p
      where m.VOcorrid = v.corrid
        and s.siteid = p.siteid
        and p.probename = m.ProbeName
        and v.ReportableVOName = '$vo'
        and m.Cores=$cores
        and m.EndTime >= '$year-$month-01'
        and m.EndTime <  '$year-$month-01' + INTERVAL 1 MONTH
        and m.DistinguishedName = '$user_esc'
        and s.SiteName = '$resource';
   " | mysql --defaults-extra-file=$loc/qqq | tail -n +2`
}

sum_results () {
   echo $results | grep NULL >/dev/null
## sum up the results for this user, there may be more than one resource in this resource group
   if [ "${results/'NULL'}" = "$results" ] ; then
       now=`date`
       x=`echo $results | awk '{ print $1 }'`
       wall=`echo "$wall+$cores*$x" | bc`

       x=`echo $results | awk '{ print $2 }'`
       cpu=`echo "$cpu+$x" | bc`

       x=`echo $results | awk '{ print $1 }'`
       nwall=`echo "$nwall+$cores*$x*$nf" | bc`

       x=`echo $results | awk '{ print $2 }'`
       ncpu=`echo "$ncpu+$x*$nf" | bc`

       x=`echo $results | awk '{ print $3 }'`
       kjobs=`echo "$kjobs+$x" | bc`

## convert start/end to linux time, find biggest,smallest
       x=`echo $times | awk '{ print $3, $4}'`
       x=`date --date="$x" +%s`

       if [ "$x" -lt "$min_d" ]; then
           min_d=$x
       fi
       x=`echo $times | awk '{ print $5, $6}'`
       x=`date --date="$x" +%s`
       if [ "$x" -gt "$max_d" ]; then
           max_d=$x
       fi
   fi
}

do_resource () {
## get the resource group for this resource
   rg=`res_rg $resource`
   if [ "${rg}" = "${unique_rg}" ]; then
       get_nf       ## Normalization factor
       get_results  ## get summed CPU and Wall time for this user on this resource
       get_times    ## find the max and min job end times for the jobs defining usage.
       sum_results  ## sum up the results for this user, there may be more than one resource in this resource group
   fi
}

get_user () {
   mlog "Getting user list"
   user=`echo "use gratia ;
     select distinct m.DistinguishedName
       from MasterSummaryData m
          , VONameCorrection v
      where m.VOcorrid = v.corrid
        and v.ReportableVOName = '$vo'
        and m.Cores = $cores
        and m.EndTime >= '$year-$month-01'
        and m.EndTime <  '$year-$month-01' + INTERVAL 1 MONTH
      limit $user_index,1;
   " | mysql --defaults-extra-file=$loc/qqq | tail -n +2`
}

get_resources () {
## find all resources used by this user
   mlog "Getting resource list for user $user"
   resources=`echo "use gratia ;
     select distinct s.SiteName
       from MasterSummaryData m
          , VONameCorrection v
          , Site s
          , Probe p
      where m.VOcorrid = v.corrid
        and s.siteid = p.siteid
        and p.probename = m.ProbeName
        and v.ReportableVOName = '$vo'
        and m.Cores=$cores
        and m.EndTime >= '$year-$month-01'
        and m.EndTime <  '$year-$month-01' + INTERVAL 1 MONTH
        and m.DistinguishedName = '$user_esc';
   " | mysql --defaults-extra-file=$loc/qqq | tail -n +2`
}

do_user_index () {
   get_user

   if [ -z "$user" ] ; then
## emplty user name, account as "generic"
       user="generic $vo user"
   fi
## escape user dn, which can contain apostrophies...
   user_esc=${user//"'"/"''"}
## find all resources used by this user
   get_resources
   size=${#resources}
   if [ "$size" -gt "$nlimit" ] ; then
## have a non-null resources list, find the resource groups of the resources
       rgs=`for res in $resources ; do res_rg $res ; done`
       echo $rgs | wc >>$logdir/multicore.log
       unique_rgs=`sort -u <<< "${rgs// /$'\n'}"`
       echo $unique_rgs | wc >>$logdir/multicore.log
       for unique_rg in $unique_rgs ; do
           do_unique_rg
       done
   fi
}

get_nusers () {
## count users for this month
   nusers=`echo "use gratia ;
     select count(distinct m.DistinguishedName)
       from MasterSummaryData m
          , VONameCorrection v
      where m.VOcorrid = v.corrid
        and v.ReportableVOName = '$vo'
        and m.Cores = $cores
        and m.EndTime >= '$year-$month-01'
        and m.EndTime <  '$year-$month-01' + INTERVAL 1 MONTH;
   " | mysql --defaults-extra-file=$loc/qqq | tail -n +2`
}

do_vo () {
   mlog "Starting an $cores core report for $vo"

## count users for this month
   get_nusers

   mlog "Found $nusers users"

   for user_index in `seq 0 $nusers` ; do
       do_user_index
   done
   mlog "Finished an $cores core report for $vo"
}

get_coreslist () {
    coreslist=`echo "use gratia ;
      select distinct m.Cores
        from MasterSummaryData m
           , VONameCorrection v
       where m.VOcorrid = v.corrid
         and v.ReportableVOName in ($volist_in)
         and m.EndTime >= '$year-$month-01'
         and m.EndTime <  '$year-$month-01' + INTERVAL 1 MONTH;
    " | mysql --defaults-extra-file=$loc/qqq | tail -n +2`
}

main () {
    date_init
    param_init
    log_init

    {
    ## add header, once per upload
    echo "APEL-summary-job-message: v0.3"

    volist="atlas alice cms enmr.eu"
    volist_in=$(perl -le "print join ',', map \"'\$_'\", @ARGV" $volist)

    get_coreslist

    for cores in $coreslist ; do
       for vo in $volist ; do
           do_vo
       done
    done

    }>$pubdir/send/${month}_$year.apel

    ## post generation section
    chmod ugoa+rw $pubdir/send/${month}_$year.apel
    cp $pubdir/send/${month}_$year.apel $pubdir/tmp/current.apel
}

main

