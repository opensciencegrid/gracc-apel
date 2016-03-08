#!/usr/bin/python

import time
import sys
import os

if len(sys.argv) != 2 or sys.argv[1].startswith('-'):
    print >>sys.stderr, "Usage: %s rginfo.txt" % os.path.basename(__file__)
    sys.exit(0)

rginfo_file = sys.argv[1]

""" FIELDS:
 1  Reource Group       : BNL-ATLAS
 2  NF                  : 10.05
 3  VO                  : atlas
 4  Jobs                : 2836398
 5  CPU Hours           : 8278719
 6  Wall Hours          : 10043800
 7  Norm CPU Hours      : 83201123
 8  Norm Wall Hours     : 100940174
 9  First Reported      : 2015-05-01
10  Last Reported       : 2015-05-31
11  Reported At         : 2015-06-09 14:41:36
12  Federation Name     : BNL_ATLAS_1
13  Resources Reporting : "BNL_ATLAS_1","BNL_ATLAS_2","BNL_ATLAS_3","BNL_ATLAS_4","BNL_ATLAS_5","BNL_ATLAS_6","BNL_ATLAS_7","BNL_ATLAS_8"
14  Month               : 05
15  Year                : 2015
"""

field_names = """
    resource_group nf vo jobs cpu wall ncpu nwall first_reported last_reported
    reported_at federation resources_reporting month year
""".split()

int_fields = """
    jobs cpu wall ncpu nwall first_reported last_reported reported_at
""".split()

def mkdate(epoch):
    return time.strftime("%Y-%m-%d", time.gmtime(epoch))

def mkdate_time(epoch):
    return time.strftime("%Y-%m-%d %H:%M:%S", time.gmtime(epoch))

def sec2hrs(s):
    return int(s/3600.0)

class RGInfo:
    def __init__(self, line):
        items = line.rstrip('\n').split('\t')
        if len(items) != len(field_names):
            print >>sys.stderr, "explode!"
            sys.exit(1)
        for i,field in enumerate(field_names):
            setattr(self, field, items[i])

        self.nf = set(map(float, self.nf.split()))
        for field in int_fields:
            setattr(self, field, int(getattr(self, field)))
        self.resources_reporting = set(self.resources_reporting.split())

    def __iadd__(self, other):
        self.nf    |= other.nf
        self.jobs  += other.jobs
        self.cpu   += other.cpu
        self.wall  += other.wall
        self.ncpu  += other.ncpu
        self.nwall += other.nwall
        self.first_reported = min(self.first_reported, other.first_reported)
        self.last_reported  = max(self.last_reported, other.last_reported)
        self.reported_at    = max(self.reported_at, other.reported_at)
        self.resources_reporting |= other.resources_reporting
        return self

    def __str__(self):
        sfields = []
        sfields.append(self.resource_group)
        nf = min(self.nf)
        if len(self.nf) > 1:
            print >>sys.stderr, "Warning, resource group %s has multiple" \
                " unique values for NF: (%s); using %s" % (
                    self.resource_group, ', '.join(map(str,self.nf)), nf)
        sfields.append(nf)
        sfields.append(self.vo)
        sfields.append(self.jobs)
        # convert the cpu/wall duration fields from seconds to hours
        sfields.append(sec2hrs(self.cpu))
        sfields.append(sec2hrs(self.wall))
        sfields.append(sec2hrs(self.ncpu))
        sfields.append(sec2hrs(self.nwall))

        sfields.append(mkdate(self.first_reported))
        sfields.append(mkdate(self.last_reported))
        sfields.append(mkdate_time(self.reported_at))
        sfields.append(self.federation)

        sfields.append(','.join('"%s"' % x for x in self.resources_reporting))
        sfields.append(self.month)
        sfields.append(self.year)

        return '\t'.join(map(str, sfields))

totals = {}
for line in open(rginfo_file):
    rginfo = RGInfo(line)
    key = (rginfo.resource_group, rginfo.vo)
    if key not in totals:
        totals[key] = rginfo
    else:
        totals[key] += rginfo

for key in sorted(totals.keys()):
    print totals[key]

