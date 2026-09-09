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

4. **GitHub repository deleted and recreated.** Confirmed 2026-09-08: the old
   commit SHAs no longer resolve and the old raw file returns 404. A force-push
   was rejected as insufficient — it leaves unreachable commits addressable by
   SHA (e.g. `/commit/d9297e2`) until GitHub Support garbage-collects them.

## Decision: the password was not rotated

Decided by the repo owner, 2026-09-09. `backend/application-local.properties`
still holds the value that was briefly public.

**What supports the decision.** The account is scoped to `@'localhost'`. A
MySQL grant scoped to `localhost` is refused for any connection that does not
originate on that machine, and the server is not reachable from outside it.
Whoever holds the password can do nothing with it without already having access
to the laptop — at which point the password is not the weak link. The practical
risk is genuinely low.

**What does not support it.** "Nobody saw it" cannot be established, and the
decision should not rest on it. GitHub publishes a real-time firehose of public
repository events, and automated scrapers clone new public repos within seconds
to grep them for credentials. The 0 stars / 0 forks / 0 watchers observed at
discovery measure *human* interest; bots do not star anything. The sound basis
for this decision is that the credential is unusable remotely — not that the
exposure went unnoticed.

**What would reverse it:**
- Discovering the password was reused anywhere else (below) — the real risk.
- Binding MySQL beyond `localhost`, or widening the grant past `@'localhost'`.
- Reusing these credentials on any deployed instance.

Rotating remains a one-command change and is still worth doing whenever
convenient — if only to prove the gitignored-config setup works end to end:

```sql
ALTER USER '<db-user>'@'localhost' IDENTIFIED BY '<new-strong-password>';
FLUSH PRIVILEGES;
```

## Still outstanding

1. **Check for password reuse.** If this value was used anywhere else — another
   database, a server, an email or personal account — rotate it there. Reuse is
   what turns a harmless local-only credential into a real one, and it is the
   one part of this exposure that none of the work above mitigates.

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
