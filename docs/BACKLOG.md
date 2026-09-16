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
| F1 | CRITICAL | No authentication on any endpoint | Done | `f6e2b77`, `b251ea5`, `fe82165`, `26cf001`, `13942a2`, `1831b5d`, `456bb76`, `c2ba0a8`, `1f19a2e`, `95d9164`, `feat(backend): restrict the full leave list to supervisors` | Accepted limits: a role change takes effect when the user's token expires (up to 8h); tokens cannot be revoked early. The app talks HTTP, not HTTPS (B14) |
| F2 | CRITICAL | Passwords stored and compared in plaintext | Done | `f0aa251` | Local test users must be re-registered |
| F3 | CRITICAL | Password returned in API responses | Done | `a97a5b0`, `c39d4c8` | |
| F4 | CRITICAL | DB credentials committed to git | Done, one step left | `1b885a6`, `fc2af8c`, `2a1a455` | Owner: check the password wasn't reused elsewhere (`F4-REMEDIATION.md`) |
| F5 | CRITICAL | Anyone can register as SUPERVISOR | Done | `a97a5b0` | |
| F6 | HIGH | Entities bound from request bodies | Done | `a97a5b0`, `c39d4c8`, `d48a52e` | |
| F7 | HIGH | Leave-request filter is cosmetic | Done | `95d9164`, `feat(backend): restrict the full leave list to supervisors` | |
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
| F20 | LOW | Dead code, unused imports, debug artifact | Partial | `a97a5b0`, `c39d4c8`, `feat(frontend): move account creation to the supervisor's employee list` | `profile_screen.dart:143` (`_buildStatColumn`) |
| F21 | HIGH | Flutter test suite does not compile | Done | `5c6ae2e` | |
| F22 | HIGH | No endpoint tests | Partial | `a97a5b0`, `c39d4c8`, `88ff852`, `d48a52e` | 11 of 32 endpoints tested (the audit counted 25) |
| F23 | MEDIUM | Tests ran against the developer's MySQL | Done | `5e04e5a` | |
| F24 | MEDIUM | Session is a mutable global | Open | | |
| F25 | MEDIUM | `BuildContext` across async gaps | Open | | More likely since F1 step 3b: a rejected token closes every screen, possibly mid-request, so a missing `mounted` check now logs "setState() called after dispose()". Also `employee_details_screen.dart` delete dialog: pops two routes, then shows its snackbar through the popped context, so "deleted successfully" likely never appears |
| F26 | MEDIUM | Debug `print`s ship in the app | Open | | |
| F27 | LOW | Hard-coded backend base URL | Open | | |
| F28 | LOW | Chat polls every 3 s | Open | | |
| F29 | LOW | `fromJson` assumes every field is present | Open | | |
| F30 | LOW | No shift-overlap constraint | Open | | |

Totals: 12 done · 4 partial · 14 open.

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

**B7 · MEDIUM · `deleteUser` forgets news items, so deleting an author fails** — found 2026-09-13
Where: `UserService.deleteUser` clears `messages`, `leaves_requests` and
`shifts` before deleting the user, but not `news_items`, whose `author` column
is a foreign key to `users`.
Why it matters: deleting a user who ever posted news hits a foreign-key
constraint error. `UserController.deleteUser` catches `RuntimeException` and
answers 500, so the client is told "server error" for what is really "this user
still has news items". Employees cannot post news today, so only supervisors
trigger it, which is why it has gone unnoticed.
Relates to: F12 (deleteUser cascades by hand across repositories) — this is the
fifth repository it forgot; F14 (every exception becomes a 404/500).
Fix idea: decide what should happen to a departed author's news (reassign,
keep with a null author, or delete) and enforce it in one place. Database-level
`ON DELETE` rules or JPA cascades would remove the hand-written list entirely.

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

**B8 · MEDIUM · Nobody can change their own password** — found 2026-09-14
Where: `UserController` has no password endpoint; `UpdateUserRequest` carries
only name, email and phone.
Why it matters: the first supervisor keeps the password from
`application-local.properties` forever, and once supervisors create accounts
(F1 step 5) every employee keeps the password a supervisor typed for them.
Someone else knowing your password defeats the point of logging in.
Relates to: F1.
Fix idea: `PUT /api/v1/users/me/password` taking the current and the new
password, checked with `PasswordEncoder.matches`. Needs F1 step 7 (identity
from the token) so a user can only change their own.

**B9 · LOW · Future milestone: several companies in one app** — found 2026-09-14
Where: the whole data model; nothing records which company a user, shift,
leave request, message or news item belongs to.
Why it matters: agreed on 2026-09-14 to build for one company for now. Offering
the app to many companies means a `Company` table, a `company_id` on every
table, and a company filter on every query. Missing that filter in one place
leaks one company's data to another.
Fix idea: do it after F1 and F7, when identity and ownership checks exist; the
JWT can then carry the company id.

**B10 · LOW · Future milestone: invite employees instead of setting their password** — found 2026-09-14
Where: account creation (after F1 step 5, only supervisors create accounts and
choose the starting password).
Why it matters: real shift apps send the employee an invitation link and let
them choose their own password, so the supervisor never knows it.
Relates to: B8.
Fix idea: a one-time, expiring invitation token stored server-side; the
employee sets a password with it. Needs an email or SMS sender, which is a new
dependency.

**B11 · LOW · `registerNewEmployee` also creates supervisors** — found 2026-09-14
Where: `UserService.createFirstSupervisorIfNone` reuses `registerNewEmployee`,
which keeps any role already set.
Why it matters: the name says "employee", so a reader assumes the role is always
EMPLOYEE. The only thing stopping a client from choosing its role is that
`UserController.toNewUser` leaves it unset.
Fix idea: rename to `registerUser` and let the caller pass the role explicitly,
when F1 step 5 changes who can register.

**B12 · LOW · Controller base paths are written three different ways** — found 2026-09-14
Where: `UserController` maps `"api/v1/users"` (no leading slash),
`ShiftController` maps `"/api/v1/"` (trailing slash, with method paths also
starting with `/`), the others `"/api/v1/<resource>"`.
Why it matters: Spring normalises all three today, but URL rules in
`SecurityConfig` (F1 steps 4–5) are matched against the real path, and a rule
written for one spelling is easy to get wrong for another.
Fix idea: use `"/api/v1/<resource>"` everywhere; split `ShiftController`'s
user-scoped routes out, or map it to `/api/v1` without the trailing slash.

**B13 · MEDIUM · Tests read the developer's `application-local.properties`** — found 2026-09-14
Where: `application.properties` imports `optional:file:./application-local.properties`,
and Maven runs the tests from `backend/`, so every `@SpringBootTest` loads the
developer's personal settings.
Why it matters: a test's result depends on whose machine runs it. It already
happened: once the local file had `app.first-supervisor.*`, the seeder created a
real supervisor at test startup, outside any transaction, and
`UserServiceTest.createsTheFirstSupervisorWhenNoneExists` failed on that machine
only. Stopgap in place: `TestProperties` overrides the JWT secret and blanks the
seeder, but any setting added to the local file later leaks in the same way.
Relates to: F23 (tests used to run against the developer's MySQL).
Fix idea: import the local file only under a `local` Spring profile
(`spring.config.activate.on-profile=local` document, or
`application-local.properties` loaded by profile name), and start the app with
that profile. Tests then never see it.

**B14 · MEDIUM · The app talks to the API over plain HTTP, and now sends a token** — found 2026-09-14
Where: `ApiService.baseUrl` is `http://10.0.2.2:8080/api/v1`.
Why it matters: since F1 step 3 every request carries `Authorization: Bearer …`.
Over plain HTTP anyone on the same network can read that header and use the
token as that user until it expires (8h). The login request already sent the
password this way. Harmless between the emulator and the developer's own PC;
not acceptable on any real network.
Relates to: F27 (hard-coded backend base URL) — fix both together.
Fix idea: serve the backend over HTTPS (or behind a reverse proxy that does),
and make the base URL configurable per build so production can only be
`https://`.

**B15 · LOW · CLAUDE.md says the app uses Riverpod; it does not** — found 2026-09-14
Where: `CLAUDE.md` lists "Flutter 3.x, Dart, Riverpod"; `frontend/pubspec.yaml`
has no Riverpod package. State lives in the static `Session` class (F24).
Why it matters: the project instructions describe a different app than the
code. A reader, or an assistant, following them will look for providers that do
not exist, or add Riverpod code that does not fit.
Relates to: F24 (session is a mutable global).
Fix idea: decide whether Riverpod is the plan. If yes, adopt it when F24 is
fixed; if not, correct `CLAUDE.md` now.

**B16 · LOW · Screens assume `Session.currentUser` is never null** — found 2026-09-14
Where: `Session.currentUser!` in `chat_screen.dart:42` and in several
`ApiService` methods (`postNews`, `submitLeaveRequest`, `getMyShifts`,
`getChatHistory`, `sendMessage`).
Why it matters: since F1 step 3b the session can be cleared while a request is
still running (the chat polls every 3 s). Code that resumes after its `await`
then hits `!` on null and throws. Today a surrounding `try/catch` swallows it in
most places, so nothing visible happens, but that is luck, not design.
Relates to: F24 (session is a mutable global), F25 (async gaps).
Fix idea: read the user once before the `await` and use that local value, or
stop when it is null. Better, once F1 step 7 lands, the server takes identity
from the token and the client stops sending its own id at all.

**B18 · LOW · The messages list shows your own name for conversations you started** — found 2026-09-15
Where: `messages_list_screen.dart` shows `msg.senderName` for every row, and on
tap builds the chat partner as `User(name: msg.senderName, role: "EMPLOYEE")`.
Why it matters: for a message you sent, the sender is you, so the row and the
chat screen's title show your own name instead of the person you wrote to. The
role is hard-coded, so a supervisor you chat with is labelled an employee.
Messages also appear once per message, not once per conversation.
Relates to: F16 (inconsistent API shapes) — the message response has sender
and receiver, but the client only reads the sender's name.
Fix idea: pick the other person (`senderId == me ? receiver : sender`) for both
name and id, take the role from the response instead of hard-coding it, and
group rows by that person.

**B19 · MEDIUM · A leave request with no reason silently fails** — found 2026-09-15
Where: `leave_requests_screen.dart` labels the field "Λόγος (Προαιρετικά" —
optional, and missing its closing bracket — but `CreateLeaveRequest.reason` is
`@NotBlank` on the server. `ApiService.submitLeaveRequest` never looks at the
response.
Why it matters: an employee who leaves the reason empty gets a 400 they never
see. The dialog closes as if the request was filed, and nothing was saved — they
may simply not show up for work believing their leave is pending.
Relates to: B1 (validation messages never reach the client), F15.
Fix idea: decide whether a reason is required. Then make the label and the
server agree, and have `submitLeaveRequest` check the status and tell the user
when it failed.

---

## Done

**B4 · LOW · No record of which audit findings are closed** — found 2026-09-10
Fixed by: the **Audit status** table above, in commit
`docs(backlog): add the audit status table (B4)`.

**B17 · MEDIUM · Logging out from the dashboard kept the user and the token** — found 2026-09-15
Where: `HomeScreen`'s logout button only called `Navigator.pop`, and
`LoginScreen` opened the dashboard with `Navigator.push`.
Why it mattered: the app showed the login page while `Session` still held the
user and a valid token, so anyone picking up the phone was still "logged in"
to the API. The phone's back button did the same from the dashboard. Only the
profile screen's logout cleared the session (since F1 step 3).
Relates to: F1, F24.
Fixed by: `fix(frontend): clear the session when logging out from the dashboard`.
The button now calls `Session.clear()` and goes to `/login` removing every
screen; login replaces itself with the dashboard (`pushReplacement`), so back
cannot reach the login page while logged in.
