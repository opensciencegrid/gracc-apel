#!/bin/bash

loc=$(dirname "$0")

mysql --defaults-extra-file="$loc/qqq" -sr < "$loc/oneshot.sql"
