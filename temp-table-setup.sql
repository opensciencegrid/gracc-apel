-- defs from oim tables
create temporary table oim_resource
( site                text
, resource_group      text
, fqdn                text
, apel_normal_factor  double
, accounting_name     varchar(256)
);

-- auxilary lookup tables from files
create temporary table normal_hepspec
( resource_group      text
, normal_factor       double
, PRIMARY KEY (resource_group)
);

create temporary table rgmap
( resource            text
, resource_group      text
, PRIMARY KEY (resource)
);

create temporary table volist
( vo                  text
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

load data local infile 'tsv/oim-tables.tsv'     into table oim_resource;
load data local infile 'tsv/normal_hepspec.tsv' into table normal_hepspec;
load data local infile 'tsv/RGMap.tsv'          into table rgmap;
load data local infile 'tsv/VOList.tsv'         into table volist;
load data local infile 'tsv/gratia_summary.tsv' into table gratia_summary;

