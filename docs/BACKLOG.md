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
| F8 | HIGH | `ddl-auto=update` is the only schema management | Done | `4cd3b82`, `feat(backend): let Hibernate validate the schema, not change it` | The developer's local DB had drifted (`shifts.user_id` nullable; fresh DBs have `NOT NULL`); fixed by hand before baselining it at V1. Every schema change is now a new `V<n>__*.sql` file (F13's rename, F15's longer text limit, B25) |
| F9 | HIGH | No pagination | Done | `6049f24`, `feat: page the message, leave, shift and user lists` | Every list is a `PageResponse` with a fixed server-side sort and at most 100 rows, except the two shift calendars (`GET /shifts`, `/users/{id}/schedule`), which need a date range of at most 366 days instead (decided 2026-09-22: a calendar needs every shift of its month). The app reads only page 0 (B26) |
| F10 | MEDIUM | N+1 queries on list endpoints | Done | `80af758`, `perf(backend): load shift, leave and news users in the list query` | Measured before the fix: an inbox of 3 messages from 3 senders took 5 statements; now every list page is 1 (`QueryCountIntegrationTest`). Single-item endpoints still load their users lazily after the query, and a list query without `@EntityGraph` would quietly bring the N+1 back (B28) |
| F11 | MEDIUM | Writes without a transaction boundary | Open | | Also: the `deleteBy...` repository methods use `jakarta.transaction.Transactional`, not Spring's, and put it on the repository instead of the service |
| F12 | MEDIUM | `deleteUser` cascades by hand | Open | | |
| F13 | LOW | No indexes; misspelled column | Done | `5ceb207`, `perf(backend): index each list query's filter and sort` | Column renamed by V2. V3 indexes every list query except the unfiltered leave list; checked with EXPLAIN on seeded data, not by a test (on small tables MySQL rightly prefers a full scan). The chat still sorts its own rows, since it reads two ranges (7→8, 8→7) |
| F14 | HIGH | Every exception becomes a 404 | Done | `071e61f`, `0449aaa`, `e5f9e0a`, `d06629a` | B1 and B2 closed with it |
| F15 | MEDIUM | No input validation | Done | `a97a5b0`, `c39d4c8`, `d48a52e`, `140a27c`, `a3ad93f`, `feat(backend): cap free-text fields at the column length` | Overnight shifts are allowed (decided 2026-09-18): only equal start and end is rejected. Free text is capped at 255 characters to match the `VARCHAR(255)` columns; a longer limit needs a migration first (F8) |
| F16 | MEDIUM | Inconsistent API shapes | Partial | `e5f9e0a` | Done by F14: `ResponseEntity<?>` is gone, `DELETE /users/{id}` answers 404 not 500, login is no longer Greek. Left: `DELETE /messages/{id}` returns a string (B21), the `/leaves/users/{id}/leaves` path, `ShiftController`'s base path and `UserController`'s missing leading slash (B12) |
| F17 | LOW | Broken URL in a dead client method | Open | | Now `api_service.dart:226` (`getMyShifts`). Since F9 it would also parse a list where the server sends a page - delete it rather than fix it |
| F18 | MEDIUM | `UserService` mixes constructor and field injection | Done | `ee2af05` | |
| F19 | LOW | DTOs split across two packages | Done | `c39d4c8` | |
| F20 | LOW | Dead code, unused imports, debug artifact | Partial | `a97a5b0`, `c39d4c8`, `feat(frontend): move account creation to the supervisor's employee list` | `profile_screen.dart:143` (`_buildStatColumn`) |
| F21 | HIGH | Flutter test suite does not compile | Done | `5c6ae2e` | |
| F22 | HIGH | No endpoint tests | Partial | `a97a5b0`, `c39d4c8`, `88ff852`, `d48a52e`, `071e61f`, `e5f9e0a`, `d06629a`, `a3ad93f`, `feat(backend): cap free-text fields at the column length` | 14 of 32 endpoints tested (the audit counted 25). F14 added the first tests that assert 404, 500 and error bodies at all |
| F23 | MEDIUM | Tests ran against the developer's MySQL | Done | `5e04e5a` | |
| F24 | MEDIUM | Session is a mutable global | Open | | |
| F25 | MEDIUM | `BuildContext` across async gaps | Open | | More likely since F1 step 3b: a rejected token closes every screen, possibly mid-request, so a missing `mounted` check now logs "setState() called after dispose()". Also `employee_details_screen.dart` delete dialog: pops two routes, then shows its snackbar through the popped context, so "deleted successfully" likely never appears |
| F26 | MEDIUM | Debug `print`s ship in the app | Open | | |
| F27 | LOW | Hard-coded backend base URL | Open | | |
| F28 | LOW | Chat polls every 3 s | Open | | |
| F29 | LOW | `fromJson` assumes every field is present | Open | | |
| F30 | LOW | No shift-overlap constraint | Open | | |

Totals: 17 done · 3 partial · 10 open.

---

## Open

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
Since F9: the list merges page 0 of the inbox with page 0 of sent (50 each),
so a conversation older than both pages is missing. Grouping on the phone
cannot fix that; a server endpoint that returns the latest message per
conversation can.

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

**B20 · LOW · "Email already taken" answers 400 where 409 Conflict belongs** — found 2026-09-16
Where: `UserService.registerNewEmployee` and `updateUser` throw
`IllegalStateException`; `ApiExceptionHandler` maps that type to 400.
Why it matters: 400 says "your request was malformed", but the request was
perfectly well formed - it lost a race with an email that already exists. 409
is the code a client can act on differently (offer to log in instead of
re-typing the form). Mapping a JDK exception type to a status is also loose:
any `IllegalStateException` from a library would be reported as the caller's
fault.
Relates to: F14 (decided during it, deliberately out of scope), F16.
Fix idea: a `DuplicateEmailException` mapped to 409, and move the BCrypt
72-byte limit into validation (F15) rather than an `IllegalStateException`.
Then `IllegalStateException` can be dropped from the advice entirely and fall
into the 500 catch-all, where it belongs.
Not with `@Size(max = 72)` (corrected 2026-09-18): `@Size` counts characters,
BCrypt counts UTF-8 bytes, and a Greek letter is two bytes - a 50-letter Greek
password passes `@Size` at 100 bytes. It needs a small custom constraint that
counts bytes, like `@ValidLeaveDates` does for its rule.

**B21 · LOW · `DELETE /messages/{id}` returns a string where every other delete returns 204** — found 2026-09-16
Where: `MessageController.deleteMessage` returns `ResponseEntity.ok("Message
deleted successfully")`; `/users/{id}`, `/shifts/{id}` and `/news/{id}` all
return 204 with no body.
Why it matters: the client needs a special case for this one route, and the
string is user-facing copy in English sitting in a controller - the same thing
B2 fixed for login. The Flutter app has no `deleteMessage` at all (nothing in
`ApiService` calls `DELETE /messages/{id}`), so changing it breaks nothing
today.
Relates to: F16 (it is one of that finding's bullets).
Fix idea: return 204 like the others; delete the string.

**B22 · LOW · "Not found" messages are worded four different ways** — found 2026-09-16
Where: the `ResourceNotFoundException` messages - `"User not found"`,
`"News item not found"`, `"Message not found"`, `"Shift not found with id 3"`,
`"Leave Request Not Found with Id: 3"`.
Why it matters: since F14 these are the `detail` field of the error body, so
they are part of the API, not internal text. Three casings, two formats, and
only some include the id.
Relates to: F14.
Fix idea: settle on one shape - `"<Resource> not found: <id>"` - and apply it
at all eight throw sites. Cosmetic, so it was kept out of the F14 commits to
leave those mechanical.

**B24 · MEDIUM · Assigning a shift with a mistyped time fails without a word** — found 2026-09-18
Where: `shifts_screen.dart:190-212`. Start and end are free-text fields labelled
"HH:mm"; `ApiService.assignShift` returns `false` on any non-2xx and the dialog
does nothing with it.
Why it matters: "8:00" or "8.00" does not parse as a `LocalTime`, so the server
answers 400 and the supervisor sees the dialog just sit there, with no hint
which field is wrong. The same will apply to the shift-time rule F15 adds.
Relates to: B1 (the server now sends field errors), B19 (same silent-failure
pattern for leave), F15.
Fix idea: use `showTimePicker` so a malformed time cannot be typed, and show a
message when `assignShift` fails.

**B26 · LOW · Paged lists show only their first page** — found 2026-09-19
Where: every paged list in `ApiService` asks for page 0 only - news 20,
leaves 50, chat / inbox / sent 50, staff 100 - and nothing asks for page 1.
Why it matters: older items are still on the server but unreachable from the
app. Intended for now - F9 is about the server not sending everything - but a
user will notice once a list outgrows its page. The staff list matters most:
it feeds the assign-shift and chat pickers, so employee 101 cannot be picked.
Relates to: F9.
Fix idea: a "load more" at the end of the list (or infinite scroll with a
`ScrollController`) that fetches `page + 1` while `page < totalPages - 1` and
appends.

**B27 · MEDIUM · The chat marks messages read one HTTP request at a time, every 3 s** — found 2026-09-19
Where: `chat_screen.dart` `_loadMessages()` loops over the history and calls
`markAsRead` once per unread message it received, awaiting each.
Why it matters: opening a chat with 50 unread messages sends 50 sequential
PUTs before the screen updates; with the 3 s poll (F28) a slow round can
overlap the next one and send the same PUTs again.
Relates to: F28, F9 (once paged, only the loaded page gets marked).
Fix idea: one endpoint, e.g. `PUT /messages/chat/{otherUserId}/read`, that
marks the whole conversation read in a single UPDATE.

**B28 · LOW · Open Session In View is on, so a forgotten `@EntityGraph` fails silently** — found 2026-09-22
Where: `application.properties` does not set `spring.jpa.open-in-view`, so
Spring Boot's default `true` applies (it logs a warning about it at startup).
Why it matters: since F10 the user associations are `LAZY`. With the session
held open until the JSON is written, a list query that forgets its
`@EntityGraph` still works - it just goes back to one query per user, and no
test or error says so. The single-item endpoints already rely on it: after
`PUT /messages/{id}/read`, building the response loads sender and receiver in
two extra queries (a fixed cost, not N+1).
Relates to: F10.
Fix idea: `spring.jpa.open-in-view=false`, then fix whatever throws
`LazyInitializationException` - an `@EntityGraph` on `findById` where a
response needs the user, or building the DTO inside the service.

**B29 · LOW · `Message.timestamp` is set when the object is built, not when it is saved** — found 2026-09-22
Where: `Message.java` initialises `timestamp = LocalDateTime.now()` in the
field and has no `@PrePersist`, unlike `NewsItem.createdAt` (fixed in B25).
Why it matters: harmless today because `sendMessage` saves right away, but the
time is taken when `new Message()` runs, and nothing stops a later save from
changing it. Two entities, two patterns for the same job.
Relates to: B25.
Fix idea: the same as B25 - stamp it in `@PrePersist` and mark the column
`updatable = false`. The column is already `NOT NULL`, so no migration.

---

## Done

**B4 · LOW · No record of which audit findings are closed** — found 2026-09-10
Fixed by: the **Audit status** table above, in commit
`docs(backlog): add the audit status table (B4)`.

**B1 · MEDIUM · Validation messages never reach the client** — found 2026-09-10
Where: every endpoint with `@Valid`. The DTOs carried messages like
`"Email is required"`, but with no `@ControllerAdvice` and Spring Boot's
`server.error.include-binding-errors=never`, the app got a bare 400 and could
not tell the user which field was wrong.
Fixed by: `071e61f`, with F14. `ApiExceptionHandler.handleMethodArgumentNotValid`
adds an `errors` property to the ProblemDetail body - field name to message.

**B2 · LOW · Error bodies mix Greek and English** — found 2026-09-10
Where: `UserController.login` returned `"Λάθος email ή password"` while every
other error string was English, so the UI's language depended on which error
happened.
Fixed by: `e5f9e0a`, with F14. The server answers `"Invalid email or password"`;
the app was already choosing its own Greek text from the 401 status
(`login_screen.dart`), so nothing changed for the user. The rule settled here:
the server sends a status and English detail, the client owns the wording.

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

**B23 · MEDIUM · The leave date picker stops at 1 January 2027** — found 2026-09-18
Where: `leave_requests_screen.dart:166`, `showDateRangePicker(lastDate: DateTime(2027))`.
Why it matters: a hard-coded year that expires on its own. From now on no one can
request leave past New Year's Eve, and from 1 January 2027 `firstDate` (today) is
after `lastDate`, which is an assertion error - the leave dialog stops working
altogether. `news_screen.dart:169` has the same pattern with 2030.
Relates to: F27 (hard-coded values in the client).
Fix idea: make it relative, e.g. `DateTime.now().add(const Duration(days: 365))`.
Fixed by: `fix(frontend): let date pickers reach a year ahead, not a fixed year`.
Both pickers now end at `latestPickableDate(DateTime.now())` (`lib/utils/date_limits.dart`),
one year from today. Today is a parameter so `date_limits_test.dart` can
check 1 January 2027 directly.

**B25 · LOW · `NewsItem.createdAt` is set twice and its column is nullable** — found 2026-09-19
Where: `NewsItem.java` initialises `createdAt` in the field *and* again in
`@PrePersist onCreate()`; V1 has `created_at datetime(6) DEFAULT NULL`, while
every other timestamp column is `NOT NULL`.
Why it matters: the field initialiser is dead weight (`@PrePersist` always
overwrites it), and a nullable column lets a row with no creation time in
through any path that skips JPA, e.g. a hand-written SQL insert. The news list
sorts on this column.
Relates to: F8 (the fix is now a migration, not an entity edit alone).
Fix idea: drop the field initialiser, add `@Column(nullable = false)`, and a
`V__` migration that backfills any nulls then sets the column `NOT NULL`.
Fixed by: `fix(backend): require a creation time on every news item`.
Migration V4 backfills NULLs with 1970-01-01 (the feed is newest first, so
`NOW()` would have floated old posts to the top) and makes the column
`NOT NULL`. `createdAt` also became `updatable = false`, so no save can
rewrite it. `NewsItemSchemaIntegrationTest` inserts a NULL with plain SQL and
expects MySQL to refuse it - Hibernate's `validate` does not check nullability,
so the entity annotation alone would have proven nothing.
