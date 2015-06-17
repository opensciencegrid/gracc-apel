#!/bin/bash

loc=$(dirname "$0")

mysql -u root oim -s < "$loc/oim-tables.sql"

