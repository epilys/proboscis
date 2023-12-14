#!/bin/sh

# Copyright (c) 2023 Manos Pitsidianakis <manos@pitsidianak.is>
# Licensed under the EUPL-1.2-or-later.
#
# You may obtain a copy of the Licence at:
# https://joinup.ec.europa.eu/software/page/eupl
#
# SPDX-License-Identifier: EUPL-1.2

DATABASE_PATH="$1"

if [ -z "${DATABASE_PATH}" ]; then
  printf "Provide the path to the sqlite3 database as the only argument.\n" 1>&2
  exit 1
fi

if [ ! -f "${DATABASE_PATH}" ]; then
  printf "Database path does not exist or is not a regular file.\n" 1>&2
  exit 1
fi

command -v sqlite3 || (printf "sqlite3 binary not found in PATH.\n" 1>&2 ; exit 1)
command -v gnuplot || (printf "gnuplot binary not found in PATH.\n" 1>&2 ; exit 1)

echo 'select date, json_count from snapshot order by date;' \
  | sqlite3 -noheader -readonly "${DATABASE_PATH}" \
  | gnuplot -p -e "set terminal dumb size 120, 30; \
  set autoscale; \
  set xdata time; \
  set timefmt \"%Y-%m-%d %H:%M\"; \
  set format x \"%d-%m-%y\" ; \
  plot '-' using 1:3 with lines notitle"
