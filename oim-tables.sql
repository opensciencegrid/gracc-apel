select s.name  as site
     , rg.name as resource_group
     , r.name  as resource
     , r.fqdn
     , rw.apel_normal_factor
     , rw.accounting_name
  from resource r
  left
  join resource_wlcg rw
    on rw.resource_id = r.id
  left
  join resource_group rg
    on r.resource_group_id = rg.id
  left
  join site s
    on rg.site_id = s.id
 order by 3,2,1;

