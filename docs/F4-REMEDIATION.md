# F4 — Committed database credentials: remediation record

Finding: [`AUDIT.md` § F4](./AUDIT.md). Started 2026-09-08.

## What the exposure actually was

The MySQL username and password for `employee_shift_db` were committed in
`backend/src/main/resources/application.properties`, present in all four
commits from the initial import (`d9297e2`) onward.

They were not only in local history. The repository has a remote —
`github.com/ChristosPentelas/Employee-Shift-Management` — and it is **public**.
Both `refs/heads/main` (`85484d8`) and the tag `v0.1-thesis-baseline`
(`d9297e2`, the commit that introduced the file) had been pushed. The
credentials were confirmed readable over unauthenticated HTTP from
`raw.githubusercontent.com`.

Exposure window: repo created 2026-09-07 13:24Z, last push 14:22Z, discovered
2026-09-08 — roughly one day. At time of checking: 0 forks, 0 stars,
0 watchers, which limits incidental copying but proves nothing about scrapers.

## Done

1. **Credentials removed from the tracked config.**
   `application.properties` no longer contains `spring.datasource.username` or
   `spring.datasource.password` at all. They now come from
   `backend/application-local.properties`, which is gitignored.
   `application-local.properties.example` is committed as a template.

   Loaded with `spring.config.import=optional:file:...`, so no Spring profile
   or IDE environment-variable setup is needed. The properties were *removed*
   from `application.properties` rather than left as placeholder defaults, so
   there is exactly one source for each value and no precedence ambiguity
   between the two files.

   Verified: `mvnw test` passes and connects to MySQL 8.0.44, so the values are
   genuinely being read from the untracked file.

2. **Local history rewritten.** `git filter-branch --tree-filter` over all refs
   replaced both credential lines with `<removed-from-history>` in every
   historical version of the file; `--tag-name-filter cat` re-pointed the tag.
   Reflogs expired and `git gc --prune=now` run.

   Verified: `git grep '<old-password>' $(git rev-list --all)` returns no match. The
   password now exists in exactly one place on disk — the gitignored
   `backend/application-local.properties`.

   All commit SHAs changed as a result:

   | before | after |
   |---|---|
   | `d9297e2` | `d36d0a0` |
   | `57e09c9` | `2ecad0f` |
   | `85484d8` | `bf8b057` |
   | `7fbcd5f` | `15f88c3` |

   Backup of the pre-rewrite state (all refs) was taken as a verified
   `git bundle` before any destructive step.

3. **Audit report redacted.** `AUDIT.md` quoted the password in plaintext.
   Replaced with a placeholder so the report can be committed safely.

## Still outstanding — these are yours to do

1. **Rotate the MySQL password.** This is the only step that actually fixes the
   exposure. Everything above limits *future* leakage; none of it un-publishes a
   password that was public for a day. Treat the old value as compromised.

   ```sql
   ALTER USER '<db-user>'@'localhost' IDENTIFIED BY '<new-strong-password>';
   FLUSH PRIVILEGES;
   ```

   `<db-user>` is the `spring.datasource.username` in your local
   `backend/application-local.properties`. Put the new password in that same
   file — and nowhere else.

2. **Delete and recreate the GitHub repository**, then re-push. A force-push
   would leave the old commits addressable by SHA (e.g. `/commit/d9297e2`)
   until GitHub Support garbage-collects them on request; deleting the repo
   removes the object store outright.

3. **Consider what else that account can reach.** If this password was reused
   anywhere — another database, another project, a personal account — rotate it
   there too.

## Why the config is shaped this way

The alternative was environment variables (`${DB_PASSWORD}`), which is the more
conventional production answer and what you'd use on a real deployment. It was
not chosen here because it requires setting variables in the IntelliJ run
configuration and again for `mvnw test`, which is easy to get wrong and easy to
forget on a new machine. A gitignored properties file with a committed
`.example` template is the lower-friction pattern for local development, and it
makes the missing-configuration case obvious (the file simply isn't there)
rather than mysterious (an unset variable).

The principle in both cases is the same, and it's the one worth keeping:
**configuration that differs per environment, or that is secret, does not belong
in the artifact you version.**
