-- defs from oim tables
create temporary table oim_resource
( site                text
, resource_group      text
, resource            text
, fqdn                text
, apel_normal_factor  double
, accounting_name     varchar(256)
);

-- auxilary lookup tables from files
create temporary table normal_hepspec
( resource_group      varchar(255)
, normal_factor       double
, PRIMARY KEY (resource_group)
);

create temporary table rgmap
( resource            varchar(255)
, resource_group      text
, PRIMARY KEY (resource)
);

create temporary table volist
( sequence_num        int(10)
, vo                  varchar(255)
, PRIMARY KEY (vo)
);

create temporary table gratia_summary
( Site             varchar(255)
, VO               varchar(255)
, Cores            bigint(20)
, GlobalUserName   varchar(255)
, WallDuration     double
, CpuDuration      double
, NumberOfJobs     bigint(20)
, EarliestEndTime  int(10)
, LatestEndTime    int(10)
);

-- rg =
--  s.sitename == oim_resource.resource ? oim_resource.resource_group :
--  s.sitename == oim_resource.fqdn &&
--          len(oim_resource.fqdn) > 2  ? oim_resource.resource_group :
--  s.sitename == rgmap.resource ? rgmap.resource_group : s.sitename

-- nf =
--   s.sitename == oim_resource.resource
--   && oim_resource.apel_normal_factor > 0
--   && oim_resource.apel_normal_factor < 200
--   ? oim_resource.apel_normal_factor :
--   rg == normal_hepspec.resource_group ? normal_hepspec.normal_factor : 12

-- Site = rg

load data local infile 'tsv/oim-tables.tsv'     into table oim_resource;
-- show warnings;
load data local infile 'tsv/normal_hepspec.tsv' into table normal_hepspec;
-- show warnings;
load data local infile 'tsv/RGMap.tsv'          into table rgmap;
-- show warnings;
load data local infile 'tsv/VOList.tsv'         into table volist;
-- show warnings;
load data local infile 'tsv/gratia_summary.tsv' into table gratia_summary;
-- show warnings;

