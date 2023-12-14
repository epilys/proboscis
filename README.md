# proboscis [![License]][license]&nbsp;[![No Maintenance Intended]][no-maintenance]

[License]: https://img.shields.io/github/license/epilys/proboscis?color=white
[license]: https://github.com/epilys/proboscis/blob/main/LICENSE
[No Maintenance Intended]: https://img.shields.io/badge/No%20Maintenance%20Intended-%F0%9F%97%99-red
[no-maintenance]: https://unmaintained.tech/

Mastodon follower tracking (please do not use for unhealthy social media obsession reasons, it's for curiosity/fun only)

**SERIOUSLY TAKE IT EASY!**

## Create an sqlite3 database with this schema:

```sql
CREATE TABLE snapshot (
  id INTEGER PRIMARY KEY ASC,
  date TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  api_count INTEGER NOT NULL,
  json_count INTEGER NOT NULL,
  json TEXT NOT NULL CONSTRAINT is_valid_json CHECK(json_valid(json))
) STRICT;
```

The `STRICT` syntax is relatively new, if it's not recognized in your sqlite3 version, you can just remove it.

Why both `api_count` and `json_count`? Personally I found them not to agree,
which is what prompted me to track changes in case I can figure out a pattern
that explains it.

### Example

Do not directly copy paste this, since it includes the `> ` line prefix of the Here document.

```shell
$ sqlite3 followers.db << 'EOF'
> CREATE TABLE snapshot (
>   id INTEGER PRIMARY KEY ASC,
>   date TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
>   api_count INTEGER NOT NULL,
>   json_count INTEGER NOT NULL,
>   json TEXT NOT NULL CONSTRAINT is_valid_json CHECK(json_valid(json))
> ) STRICT;
> EOF
$ 
```

## Optionally run it on a schedule

```sh
$ crontab -e
```

append:

```crontab
# m h  dom mon dow   command
0 0,12,18 * * * /bin/bash /home/user/.local/bin/mastodon_stats.sh >> /home/user/.local/share/mastodon/run.log
```
