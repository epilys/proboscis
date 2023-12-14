-- Copyright (c) 2023 Manos Pitsidianakis <manos@pitsidianak.is>
-- Licensed under the EUPL-1.2-or-later.
--
-- You may obtain a copy of the Licence at:
-- https://joinup.ec.europa.eu/software/page/eupl
--
-- SPDX-License-Identifier: EUPL-1.2

-- Find people who unfollowed you. For research purposes only.

-- Create temporary view of tuples (snapshot_id, snapshot_id, follower
-- display_name, follower account address).
-- This allows us to compare different tuples of the same follower by date to
-- see when following started/ended.
CREATE TEMP VIEW accounts AS
  SELECT DISTINCT
    snapshot.id AS id,
    snapshot.date AS date,
    json_extract(json_each.value, '$.display_name') AS display_name,
    json_extract(json_each.value, '$.acct') AS acct
  FROM
    snapshot,
    json_each(snapshot.json);


-- Find accounts who stopped following by looking for an s1 tuple that doesn't
-- have an s2 tuple where their ids are sequential (differ by 1) and refer to
-- the same account.
SELECT DISTINCT
    s1.display_name,
    s1.acct,
    s1.date as date_followed,
    s2.date as date_unfollowed
  FROM
    accounts AS s1,
    accounts AS s2
  WHERE
      s2.id = s1.id + 1
    AND
      NOT
        EXISTS
          (
            SELECT
              1
            FROM
              accounts
            WHERE
                accounts.id > s1.id
              AND
                accounts.acct = s1.acct
          );

-- Find accounts who started following after the first snapshot by looking for
-- an s tuple that is the earliest existing one for a specific account and did
-- not exist in the first snapshot.
SELECT DISTINCT
    s.id as snapshot_id,
    s.display_name,
    s.acct,
    s.date as date_followed
  FROM
    accounts AS s
  WHERE
      NOT
        EXISTS
          (
            SELECT
              1
            FROM
              accounts
            WHERE
                accounts.id < s.id
              AND
                accounts.id > 1
                AND
                  accounts.acct = s.acct
          )
    AND
      NOT
        EXISTS
          (
            SELECT
              1
            FROM
              accounts
            WHERE
                accounts.id = 1
              AND
                accounts.acct = s.acct
          );
