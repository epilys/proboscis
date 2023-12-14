#!/usr/bin/bash

# Copyright (c) 2023 Manos Pitsidianakis <manos@pitsidianak.is>
# Licensed under the EUPL-1.2-or-later.
#
# You may obtain a copy of the Licence at:
# https://joinup.ec.europa.eu/software/page/eupl
#
# SPDX-License-Identifier: EUPL-1.2

if [ -z ${USERNAME} ] || [ -z ${INSTANCE_URL} ] || [ -z ${DATABASE_PATH} ]; then
  printf "ERROR: Please define USERNAME, INSTANCE_URL and DATABASE_PATH variables.\n\nExample values are USERNAME=user INSTANCE_URL=\"https://example.com/\" DATABASE_PATH=/tmp/proboscis.db\n" 1>&2
  exit 1
fi

if [ ! -f "${DATABASE_PATH}" ]; then
  printf "ERROR: DATABASE_PATH %s either does not exist or is not a regular file.\n" "${DATABASE_PATH}" 1>&2
  exit 1
fi

require_dependency() {
  command -v "${1}" > /dev/null || (printf "Required %s binary not found in PATH.\n" "${1}" 1>&2 ; exit 1)
}

for dep in curl jq grep awk python3 sqlite3; do
  require_dependency $dep
done

# Macos compatibility
AWK=$(command -v gawk || command -v awk)

# For Referer value:
PROFILE_URL="${INSTANCE_URL}/@${USERNAME}"
API_URL="${INSTANCE_URL}/api/v1/accounts/"

PROFILE_JSON_FILE=$(mktemp).json
FOLLOWERS_JSON_FILE=$(mktemp).json

#.schema
#CREATE TABLE snapshot (
#id INTEGER PRIMARY KEY ASC,
#date TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
#api_count INTEGER NOT NULL,
#json_count INTEGER NOT NULL,
#json TEXT NOT NULL CONSTRAINT is_valid_json CHECK(json_valid(json))
#) STRICT;

mastodon_stats(){
  # Pretend to be a browser, just in case.
  curl "${API_URL}lookup?acct=${USERNAME}" --compressed -H 'User-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10.15; rv:120.0) Gecko/20100101 Firefox/120.0' -H 'Accept: application/json, text/plain, */*' -H 'Accept-Language: en-GB,en;q=0.5' -H 'Accept-Encoding: gzip, deflate, br' -H "Referer: ${PROFILE_URL}" -H 'DNT: 1' -H 'Sec-GPC: 1' -H 'Connection: keep-alive' -H 'Sec-Fetch-Dest: empty' -H 'Sec-Fetch-Mode: cors' -H 'Sec-Fetch-Site: same-origin' -H 'Pragma: no-cache' -H 'Cache-Control: no-cache' -H 'TE: trailers' > "${PROFILE_JSON_FILE}"
  profile_json="$(cat "${PROFILE_JSON_FILE}")"
  followers_no=$(echo "${profile_json}" | jq .followers_count)
  account_id=$(echo "${profile_json}" | jq .id)

  #echo "Followers no: ${followers_no}"

  echo -n "" > "${FOLLOWERS_JSON_FILE}"
  next="${API_URL}/${account_id}/followers"

  # API responses might be paginated. In this case we must be a good user and wait a bit between requests.
  while true; do
    if [ -z "${next}" ]; then
      break;
    fi
    #echo "quering ${next}"
    response=$(curl -i -s "${next}" --compressed -H 'User-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10.15; rv:120.0) Gecko/20100101 Firefox/120.0' -H 'Accept: application/json, text/plain, */*' -H 'Accept-Language: en-GB,en;q=0.5' -H 'Accept-Encoding: gzip, deflate, br' -H "Referer: ${PROFILE_URL}/followers" -H 'DNT: 1' -H 'Sec-GPC: 1' -H 'Connection: keep-alive' -H 'Sec-Fetch-Dest: empty' -H 'Sec-Fetch-Mode: cors' -H 'Sec-Fetch-Site: same-origin' -H 'Pragma: no-cache' -H 'Cache-Control: no-cache' -H 'TE: trailers')
    #echo "got response from ${next}"
    json_resp=$(echo "$response" | tail -n1)
    echo "${json_resp}" >> "${FOLLOWERS_JSON_FILE}"
    printf "\n\n" >> "${FOLLOWERS_JSON_FILE}"
    next=$(echo "${response}" | grep link | head -n1)
    #echo "checking for headers from response"
    #echo "link header is \"${next}\""
    next=$(echo "${next}" | sed -e 's/^.\+ [<]\(.\+\)[>]; rel="next".*$/\1/') || (echo "no next found in \"${next}\"")
    if [ -z "${next}" ]; then
      break;
    fi
    #echo "next link is \"${next}\""
    sleep_secs=$(awk 'BEGIN { srand(); print int(rand()*32768)%15 }' /dev/null)
    #echo "next link is \"${next}\", sleeping for \"${sleep_secs}\""
    sleep "${sleep_secs}"
  done

  # Update database.

  python3 -c "import json, sqlite3, itertools; data = list(itertools.chain.from_iterable([json.loads(l) for l in open('${FOLLOWERS_JSON_FILE}', 'r').read().splitlines() if len(l) > 3])); db=sqlite3.connect('${DATABASE_PATH}');db.execute('INSERT INTO snapshot(api_count,json_count, json) VALUES(?,?,?)', (${followers_no},len(data),json.dumps(data)));db.commit()"
}

mastodon_stats

# Cleanup.

rm "${PROFILE_JSON_FILE}" "${FOLLOWERS_JSON_FILE}"
