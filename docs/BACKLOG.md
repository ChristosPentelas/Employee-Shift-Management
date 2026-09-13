# Backlog — things noticed while working

A living list of problems and "could be written better" spots found during
day-to-day work. `AUDIT.md` is a dated snapshot and is not edited; this file is
the opposite — add to it whenever something is noticed, and mark items done
when they are fixed.

Rules:

- One entry per problem. Give it the next `B` number; numbers are never reused.
- If it overlaps an audit finding, say which (`F14`) instead of repeating it.
- When fixed, move it to **Done** with the commit hash — or the commit subject
  when the fix and the Done entry are in the same commit (a commit cannot
  contain its own hash: the hash is computed from the content). Don't delete
  it — the history of what went wrong is part of the learning.
- When an audit fix lands, update its row in **Audit status**.

Severity uses the audit's scale: CRITICAL · HIGH · MEDIUM · LOW.

Order of work (agreed 2026-09-10): audit findings first, most severe first;
backlog items at the end — unless one touches the same code as the audit fix
in progress, in which case it goes into that fix.

---

## Audit status

Tracks the findings in `AUDIT.md`. The audit's header names commit `7fbcd5f`;
the F4 history rewrite renamed it to **`15f88c3`**, so use that in git
commands (`git log 15f88c3..HEAD`).

Status last checked 2026-09-10 against the code. "Open" on a finding no
commit mentions means nothing has changed it, not that its code was re-read.

| ID | Severity | Finding | Status | Fixed by | What's left |
|---|---|---|---|---|---|
| F1 | CRITICAL | No authentication on any endpoint | Open | | |
| F2 | CRITICAL | Passwords stored and compared in plaintext | Done | "fix(backend)!: hash passwords with BCrypt" | Local test users must be re-registered |
| F3 | CRITICAL | Password returned in API responses | Done | `a97a5b0`, `c39d4c8` | |
| F4 | CRITICAL | DB credentials committed to git | Done, one step left | `1b885a6`, `fc2af8c`, `2a1a455` | Owner: check the password wasn't reused elsewhere (`F4-REMEDIATION.md`) |
| F5 | CRITICAL | Anyone can register as SUPERVISOR | Done | `a97a5b0` | |
| F6 | HIGH | Entities bound from request bodies | Done | `a97a5b0`, `c39d4c8`, `d48a52e` | |
| F7 | HIGH | Leave-request filter is cosmetic | Open | | Needs F1 first |
| F8 | HIGH | `ddl-auto=update` is the only schema management | Open | | |
| F9 | HIGH | No pagination | Open | | |
| F10 | MEDIUM | N+1 queries on list endpoints | Open | | |
| F11 | MEDIUM | Writes without a transaction boundary | Open | | |
| F12 | MEDIUM | `deleteUser` cascades by hand | Open | | |
| F13 | LOW | No indexes; misspelled column | Open | | |
| F14 | HIGH | Every exception becomes a 404 | Open | | No `@ControllerAdvice` yet. Fold in B1 and B2 |
| F15 | MEDIUM | No input validation | Partial | `a97a5b0`, `c39d4c8`, `d48a52e` | Required fields done. Missing: end after start (leave dates, shift times); max length on message content |
| F16 | MEDIUM | Inconsistent API shapes | Open | | |
| F17 | LOW | Broken URL in a dead client method | Open | | Still at `api_service.dart:195` |
| F18 | MEDIUM | `UserService` mixes constructor and field injection | Done | `ee2af05` | |
| F19 | LOW | DTOs split across two packages | Done | `c39d4c8` | |
| F20 | LOW | Dead code, unused imports, debug artifact | Partial | `a97a5b0`, `c39d4c8` | `profile_screen.dart:143` (`_buildStatColumn`), `employee_list_screen.dart:2` (unused `session.dart` import) |
| F21 | HIGH | Flutter test suite does not compile | Done | `5c6ae2e` | |
| F22 | HIGH | No endpoint tests | Partial | `a97a5b0`, `c39d4c8`, `88ff852`, `d48a52e` | 11 of 32 endpoints tested (the audit counted 25) |
| F23 | MEDIUM | Tests ran against the developer's MySQL | Done | `5e04e5a` | |
| F24 | MEDIUM | Session is a mutable global | Open | | |
| F25 | MEDIUM | `BuildContext` across async gaps | Open | | |
| F26 | MEDIUM | Debug `print`s ship in the app | Open | | |
| F27 | LOW | Hard-coded backend base URL | Open | | |
| F28 | LOW | Chat polls every 3 s | Open | | |
| F29 | LOW | `fromJson` assumes every field is present | Open | | |
| F30 | LOW | No shift-overlap constraint | Open | | |

Totals: 10 done · 4 partial · 16 open.

---

## Open

**B1 · MEDIUM · Validation messages never reach the client** — found 2026-09-10
Where: every endpoint with `@Valid` (users, leaves, news, shifts, messages).
The DTOs carry messages like `"Email is required"`, but the project has no
`@ControllerAdvice` and no `server.error.include-binding-errors` setting, and
Spring Boot's default is to leave them out. The Flutter app gets a bare 400
and cannot tell the user which field is wrong. The messages are visible in
the test logs, so the validation itself works.
Relates to: F14 (no `@ControllerAdvice`) and the unfinished half of F15.
Fix idea: one `@RestControllerAdvice` that turns
`MethodArgumentNotValidException` into a JSON body of field → message. Doing it
together with F14 means there is one error format for the whole API.

**B2 · LOW · Error bodies mix Greek and English** — found 2026-09-10
Where: `UserController.login` returns `"Λάθος email ή password"`; validation
messages and other error strings are English.
Why it matters: the app shows whichever language the server picked, so the UI
switches language depending on which error happened.
Fix idea: settle the language in B1's error format. If the app needs Greek,
translate in Flutter from a stable error code, not from server text.

**B3 · LOW · Mockito attaches itself at runtime, which future JDKs will block** — found 2026-09-10
Where: every `mvnw test` run prints "Mockito is currently self-attaching to
enable the inline-mock-maker. This will no longer work in future releases of
the JDK."
Why it matters: no effect today on Java 21, but a JDK upgrade would break
every test that mocks, all at once.
Fix idea: configure Mockito as a `-javaagent` in the Surefire plugin, as the
warning's linked docs describe. It's only build config, no new dependency.

**B5 · LOW · No `.gitattributes`, so line endings depend on each machine's git settings** — found 2026-09-10
Where: the repo root has no `.gitattributes`. On this machine git converts
line endings only because the Git for Windows installer set
`core.autocrlf=true` system-wide, which prints `LF will be replaced by CRLF` on
every commit of a new file.
Why it matters: the repo is clean today (all 170 text files are stored as LF),
but only thanks to that one machine setting. A contributor with a different
setting can commit CRLF files, and then every line shows up as changed in the
diff. Shell scripts like `backend/mvnw` also break on Linux/CI if they get CRLF
endings (`/bin/sh^M: bad interpreter`).
Fix idea: a `.gitattributes` with `* text=auto eol=lf`, plus exceptions
`*.cmd`/`*.bat text eol=crlf` for the Windows wrappers (`mvnw.cmd`). Then run
`git add --renormalize .` and check the diff comes out empty.

**B6 · LOW · Two different `@Transactional` annotations in use** — found 2026-09-11
Where: `UserService.java` imports `jakarta.transaction.Transactional` (the Java
EE / JTA one); `UserServiceTest` uses Spring's
`org.springframework.transaction.annotation.Transactional`.
Why it matters: Spring honours both, but only its own has `readOnly`,
`rollbackFor` and `propagation`, and two annotations with the same name make
readers wonder whether they behave differently. Beginners often pick whichever
the IDE auto-imports first.
Relates to: F11 (writes without a transaction boundary) — settle this when
adding `@Transactional` to the other services.
Fix idea: use Spring's everywhere.

---

## Done

**B4 · LOW · No record of which audit findings are closed** — found 2026-09-10
Fixed by: the **Audit status** table above, in commit
`docs(backlog): add the audit status table (B4)`.
