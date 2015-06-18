
use gratia ;
SET time_zone = '+00:00';   -- not sure if this is actually correct...
                            -- but it matches the current report's numbers
SET @year = '2015';
SET @month = '05';
SET @month_start = concat(@year, '-', @month, '-01');

-- select 'APEL-summary-job-message: v0.3';
--
-- select concat( 'Site: '                   , Site
--              -- Site actually means something else in the report...
--        , '\n', 'VO: '                     , VO
--        , '\n', 'EarliestEndTime: '        , UNIX_TIMESTAMP(EarliestEndTime)
--        , '\n', 'LatestEndTime: '          , UNIX_TIMESTAMP(LatestEndTime)
--        , '\n', 'Month: '                  , @month
--        , '\n', 'Year: '                   , @year
--        , '\n', 'Infrastructure: '         , 'Gratia-OSG'
--        , '\n', 'GlobalUserName: '         , GlobalUserName
--        , '\n', 'Processors: '             , Cores
--        , '\n', 'NodeCount: '              , 1
--        , '\n', 'WallDuration: '           , WallDuration
--        , '\n', 'CpuDuration: '            , CpuDuration
-- --     , '\n', 'NormalisedWallDuration: ' , NormalisedWallDuration
-- --     , '\n', 'NormalisedCpuDuration: '  , NormalisedCpuDuration
--        , '\n', 'NumberOfJobs: '           , NumberOfJobs
--        , '\n', '%%' )
--   from (

select s.SiteName               as Site
     , v.ReportableVOName       as VO
     , m.Cores                  as Cores
     , m.DistinguishedName      as GlobalUserName
     , sum(m.WallDuration)      as WallDuration
     , sum(m.CpuUserDuration +
           m.CpuSystemDuration) as CpuDuration
     , sum(m.njobs)             as NumberOfJobs
     , UNIX_TIMESTAMP(min(m.EndTime))  as EarliestEndTime
     , UNIX_TIMESTAMP(max(m.EndTime))  as LatestEndTime
  from MasterSummaryData m
  join VONameCorrection v
    on m.VOcorrid = v.corrid
  join Probe p
    on p.probename = m.ProbeName
  join Site s
    on s.siteid = p.siteid
 where v.ReportableVOName in ('atlas','alice','cms','enmr.eu')
   and m.EndTime >= @month_start
   and m.EndTime <  @month_start + INTERVAL 1 MONTH
 group by v.ReportableVOName, m.Cores, m.DistinguishedName, s.SiteName
 order by v.ReportableVOName, m.Cores, m.DistinguishedName, s.SiteName
-- ) main
;
