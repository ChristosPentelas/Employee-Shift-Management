# Repository Audit — Employee Shift Management

Audit date: 2026-09-07
Commit audited: `7fbcd5f` (branch `main`, working tree clean)
Method: static reading of the checked-in sources. Nothing was built or run
during this audit; where a claim depends on runtime behaviour it is marked
**[inferred]**.

---

## Part 1 — Inventory

### 1.1 Platform and build

| Item | Value | Source |
|---|---|---|
| Java version | 21 (`<java.version>21</java.version>`) | `backend/pom.xml:33` |
| Spring Boot | 4.0.0 (parent POM) | `backend/pom.xml:8` |
| Build tool | Maven, with wrapper `mvnw` / `mvnw.cmd` | `backend/pom.xml`, `backend/.mvn/wrapper/maven-wrapper.properties` |
| Maven distribution pinned | Apache Maven 3.9.11, wrapper 3.3.4 | `backend/.mvn/wrapper/maven-wrapper.properties` |
| Database | MySQL, `jdbc:mysql://localhost:3306/employee_shift_db`, dialect `MySQLDialect` | `backend/src/main/resources/application.properties:4,9` |
| Schema management | Hibernate `ddl-auto=update` (no migration tool present) | `application.properties:10` |
| Dart SDK constraint | `^3.7.2`; lockfile resolves `dart >=3.7.2 <4.0.0` | `frontend/pubspec.yaml:22`, `frontend/pubspec.lock` |
| Flutter constraint (lock) | `>=3.18.0-18.0.pre.54` | `frontend/pubspec.lock` |
| Frontend state management | **None.** No Riverpod, Provider, BLoC or any state package in `pubspec.yaml`. State is `StatefulWidget` + `setState`, plus one global static class `Session`. | `frontend/pubspec.yaml:31-38`, `frontend/lib/utils/session.dart` |

> Note: `CLAUDE.md` lists "Riverpod" as the state management approach. That does
> not match the repository — Riverpod is not a declared or locked dependency.
> `CLAUDE.md` also lists Mockito as a test dependency; it is not in `pom.xml`.

### 1.2 Directory structure (2 levels)

Generated build output (`backend/target/`, `frontend/build/`, `frontend/.dart_tool/`)
and IDE folders are present on disk but **not** tracked by git — verified with
`git ls-files`.

```
backend/
  .mvn/wrapper/          maven wrapper properties
  src/main/              java + resources
  src/test/              java (no test resources dir)
  pom.xml, mvnw, mvnw.cmd, HELP.md, .gitignore, .gitattributes
  target/                (build output, untracked)

backend/src/main/java/org/example/employeeshiftmanagement/
  EmployeeShiftManagementApplication.java
  config/       SecurityConfig
  controller/   5 controllers
  dto/          LoginRequest  (the only class in this package)
  model/        5 entities + 2 enums + MessageRequest (a DTO, misplaced here)
  repository/   5 Spring Data JPA interfaces
  service/      5 services

frontend/
  lib/          main.dart, models/, screens/, services/, utils/, widgets/ (widgets/ is EMPTY)
  test/         widget_test.dart (1 file)
  android/ ios/ linux/ macos/ windows/ web/   generated platform folders
  pubspec.yaml, pubspec.lock, analysis_options.yaml, README.md, .metadata
  build/, .dart_tool/    (build output, untracked)
```

`frontend/lib` line counts: 19 files, 2152 lines. Largest: `services/api_service.dart`
(353), `screens/shifts_screen.dart` (247), `screens/news_screen.dart` (240).

### 1.3 JPA entities and relationships

Five `@Entity` classes. All use `Integer` ids with `GenerationType.IDENTITY`.
All associations are `@ManyToOne` with **no** `fetch` attribute, i.e. JPA's
default `EAGER`. There are no `@OneToMany` inverse sides, no `cascade`, no
`orphanRemoval`, and no `@Index` / `@UniqueConstraint` declarations anywhere.

| Entity | Table | Relationships | Notes |
|---|---|---|---|
| `User` | `users` | none (owning side of everything else) | `email` unique+not-null; `password` and `role` plain `String`, not-null; `phoneNumber` nullable |
| `Shift` | `shifts` | `@ManyToOne User user` → FK `user_id`, not-null | `date` (LocalDate), `startTime`/`endTime` (LocalTime), `position` |
| `LeaveRequest` | `leaves_requests` | `@ManyToOne User user` → FK `user_id`, not-null | `status` `@Enumerated(STRING)` `LeaveStatus`, defaults to `PENDING` in the field initialiser |
| `Message` | `messages` | `@ManyToOne User sender` → FK `sender_id`; `@ManyToOne User receiver` → FK **`reciever_id`** (misspelled column) | `timestamp` defaults via field initialiser; `isRead` boolean default false |
| `NewsItem` | `news_items` | `@ManyToOne User author` → FK `author_id`, **nullable** (only entity whose FK is optional) | `type` `@Enumerated(STRING)` `NewsType`; `createdAt` set by `@PrePersist`; `deadline`, `targetValue` nullable |

Enums: `LeaveStatus{PENDING, APPROVED, REJECTED}`, `NewsType{ANNOUNCEMENT, TASK, GOAL}`.
`model/MessageRequest.java` is a plain DTO (not an entity) sitting in the `model` package.

### 1.4 REST endpoints

25 endpoints across 5 controllers. **Every one of them returns or accepts JPA
entities directly** — there are no response DTOs anywhere in the codebase.

**`UserController`** — base `api/v1/users` (declared without a leading slash)

| Method | Path | Returns |
|---|---|---|
| POST | `/api/v1/users` | `User` entity, 201; 400 + message on duplicate email |
| GET | `/api/v1/users` | `List<User>`, 200 — unpaged |
| GET | `/api/v1/users/{userId}` | `User`, 200; empty 404 |
| GET | `/api/v1/users/search?email=` | `User`, 200; empty 404 |
| PUT | `/api/v1/users/{userId}` | `User`, 200; 400 + message |
| DELETE | `/api/v1/users/{userId}` | 204; 500 on any failure |
| POST | `/api/v1/users/login` | `User`, 200; 401 + Greek literal `"Λάθος email ή password"` |

**`ShiftController`** — base `/api/v1/` (mixes two resource roots)

| Method | Path | Returns |
|---|---|---|
| POST | `/api/v1/users/{userId}/shifts` | `Shift`, 201; 404 + message |
| GET | `/api/v1/shifts` | `List<Shift>`, 200 — unpaged |
| GET | `/api/v1/shifts/users/{userId}` | `List<Shift>`, 200; 404 |
| PUT | `/api/v1/shifts/{shiftId}` | `Shift`, 200; 404 |
| DELETE | `/api/v1/shifts/{shiftId}` | 204; 404 |
| GET | `/api/v1/users/{userId}/schedule?start=&end=` | `List<Shift>`, 200; 404 |

**`LeaveRequestController`** — base `/api/v1/leaves`

| Method | Path | Returns |
|---|---|---|
| POST | `/api/v1/leaves` | `LeaveRequest`, 201; 404 |
| GET | `/api/v1/leaves/users/{userId}/leaves` | `List<LeaveRequest>`, 200; 404 |
| GET | `/api/v1/leaves` | `List<LeaveRequest>`, 200 — unpaged, **all users** |
| GET | `/api/v1/leaves/filter?status=&userId=` | `List<LeaveRequest>`, 200; 404 |
| PUT | `/api/v1/leaves/{requestId}/status?status=` | `LeaveRequest`, 200; 404 |

**`MessageController`** — base `/api/v1/messages`

| Method | Path | Returns |
|---|---|---|
| POST | `/api/v1/messages?senderId=&receiverId=` | `Message`, 201; 404 |
| GET | `/api/v1/messages/chat?user1Id=&user2Id=` | `List<Message>`, 200 |
| GET | `/api/v1/messages/inbox/{userId}` | `List<Message>`, 200 |
| GET | `/api/v1/messages/sent/{userId}` | `List<Message>`, 200 |
| GET | `/api/v1/messages/unread/{userId}` | `List<Message>`, 200 |
| PUT | `/api/v1/messages/{messageId}/read` | `Message`, 200; 404 |
| DELETE | `/api/v1/messages/{messageId}` | plain-text `"Message deleted successfully"`, 200; 404 |

**`NewsItemController`** — base `/api/v1/news`

| Method | Path | Returns |
|---|---|---|
| POST | `/api/v1/news` | `NewsItem`, 201; 404 |
| GET | `/api/v1/news` | `List<NewsItem>`, 200 — unpaged |
| GET | `/api/v1/news/type/{type}` | `List<NewsItem>`, 200 |
| GET | `/api/v1/news/{id}` | `NewsItem`, 200; 404 |
| GET | `/api/v1/news/author/{authorId}` | `List<NewsItem>`, 200 |
| PUT | `/api/v1/news/{id}` | `NewsItem`, 200; 404 |
| DELETE | `/api/v1/news/{id}` | 204; 404 |

### 1.5 Existing tests

**Backend — 2 files, 7 test methods.**

| File | Type | Covers |
|---|---|---|
| `EmployeeShiftManagementApplicationTests.java` | `@SpringBootTest` smoke | Spring context loads (1 empty test) |
| `UserServiceTest.java` | `@SpringBootTest` + `@Transactional` integration | `UserService` only: register + find by id, update, delete, duplicate-email on register, find by email (+ not-found), duplicate-email on update (6 tests) |

There is no `src/test/resources`, so these tests use the production
`application.properties` and connect to the developer's real local MySQL.
No unit tests, no Mockito, no `@WebMvcTest`/`@DataJpaTest`, no controller or
repository tests. `ShiftService`, `LeaveRequestService`, `MessageService`,
`NewsItemService` and all 25 endpoints have **zero** test coverage.

The last recorded surefire run (`backend/target/surefire-reports/`, stale build
output) shows 7/7 passing.

**Frontend — 1 file, 1 test.** `frontend/test/widget_test.dart` is the
unmodified Flutter "counter increments" template. It tests a counter UI that
does not exist in this app, and it calls `const MyApp()` while `MyApp`
(`lib/main.dart:8`) declares no const constructor.

### 1.6 Dependencies

**Backend (`pom.xml`)** — all Spring versions are managed by the Boot 4.0.0 parent.

| Dependency | Scope | Status |
|---|---|---|
| `spring-boot-starter-data-jpa` | compile | current |
| `spring-boot-starter-security` | compile | current, but see F1 — it is configured to do nothing |
| `spring-boot-starter-webmvc` | compile | current (Boot 4 naming) |
| `mysql-connector-j` | runtime | current |
| `org.projectlombok:lombok` | provided/optional | current |
| `spring-boot-starter-data-jpa-test` | test | current (Boot 4 naming) |
| `spring-boot-starter-security-test` | test | current |
| `spring-boot-starter-webmvc-test` | test | current |

Nothing outdated or unmaintained. What is *missing* is more notable than what
is present: no `spring-boot-starter-validation`, no Flyway/Liquibase, no
Testcontainers, no H2, no JWT library, no Mockito, no OpenAPI/springdoc.

**Frontend (`pubspec.yaml` / `pubspec.lock`)** — 3 direct runtime deps, 1 dev dep.

| Dependency | Declared | Locked | Status |
|---|---|---|---|
| `http` | `^1.1.0` | 1.6.0 | current, maintained (Dart team) |
| `cupertino_icons` | `^1.0.8` | 1.0.8 | current |
| `table_calendar` | `^3.2.0` | 3.2.0 | current; community-maintained, release cadence is slow — worth watching, not a problem today |
| `flutter_lints` (dev) | `^5.0.0` | 5.0.0 | current |

No transitive dependency in the lockfile is flagged as discontinued.
No dependency in either project appears abandoned.

---

## Part 2 — Findings

Severity reflects the consequence if this code were deployed as-is. This is a
learning project, so several CRITICALs are "expected at this stage" — they are
still recorded at their real severity, because the point of an audit is to say
what is true, not what is excusable.

### Security

---

**F1 · CRITICAL · Every endpoint is open to the internet, unauthenticated**
`backend/.../config/SecurityConfig.java:14-17`

`csrf.disable()` plus `.anyRequest().permitAll()`. The `spring-boot-starter-security`
dependency is present but neutralised — there is no `UserDetailsService`, no
filter, no `@PreAuthorize`, no session or token handling anywhere in the backend.

**Why it matters:** anyone who can reach port 8080 can read the full staff list
with passwords, delete any employee, approve their own leave, read anyone's
private messages, and rewrite the shift schedule. The `role` field on `User`
exists but is never checked server-side — every "supervisor only" decision in
this system is made in Dart, on the client, where the user controls it
(`Session.isSupervisor()`, `frontend/lib/utils/session.dart:7`).

**Effort: L** — this is authentication + authorization from scratch, and it
touches every controller.

---

**F2 · CRITICAL · Passwords stored and compared in plaintext**
`backend/.../model/User.java:31`, `backend/.../service/UserService.java:62`,
`backend/.../controller/UserController.java:82`

`registerNewEmployee` calls `userRepository.save(user)` with the raw password.
Login does `user.getPassword().equals(loginRequest.getPassword())` — a plain
string comparison against the plaintext column. No `PasswordEncoder` bean exists
despite Spring Security being on the classpath.

**Why it matters:** one leaked database dump, backup file, or SQL-injection
elsewhere hands over every employee's actual password — which people reuse on
their email and bank. There is no recovery from this: you cannot un-leak a
plaintext password, and you cannot tell affected users "the hashes were salted".
The `.equals()` comparison is also non-constant-time, though that is a footnote
next to the storage problem.

**Effort: M** — add `BCryptPasswordEncoder`, encode on register, `matches()` on
login. The complication is migrating any rows that already exist.

---

**F3 · CRITICAL · Password field is returned in API responses**
`backend/.../controller/UserController.java:33,40,48,61,83`
(consequence of `model/User.java:31` being serialized directly)

Because controllers return the `User` entity and the entity has a `password`
field with a Lombok `@Getter`, Jackson serializes it. `GET /api/v1/users`
returns every user's plaintext password. So does login, user-by-id, search, and
update. The Flutter client depends on this: `User.fromJson`
(`frontend/lib/models/user_model.dart:25`) reads `json['password']` as a
required non-null field, so the leak is load-bearing — removing it breaks the
app until the model is changed too.

It gets worse in transit: `ApiService.getInbox` prints the raw response body to
the console (`frontend/lib/services/api_service.dart:306`), and the whole app
talks plain `http://`, not `https://` (`api_service.dart:12`).

**Why it matters:** any employee — or anyone at all, given F1 — can call one
unauthenticated GET and walk away with the entire company's credentials in
cleartext. This turns F2 from "bad if the DB leaks" into "already leaked to
anyone who asks".

**Effort: M** — introduce a `UserResponse` DTO (which `CLAUDE.md` already
mandates), and update `User.fromJson` on the Flutter side to stop requiring the
field.

---

**F4 · CRITICAL · Live database credentials committed to git**
`backend/src/main/resources/application.properties:5-6`

```
spring.datasource.username=<redacted>
spring.datasource.password=<redacted — see note below>
```

Verified present in **all four commits** in the repository's history, starting
with `d9297e2` ("import thesis codebase as starting baseline").

> **Update 2026-09-08 — this is worse than first assessed.** The repository has
> a remote, `github.com/ChristosPentelas/Employee-Shift-Management`, and it is
> **public**. `origin/main` and the tag `v0.1-thesis-baseline` (which points at
> the commit that introduced the file) were both pushed. The credentials were
> confirmed readable over unauthenticated HTTP. Repo created 2026-09-07 13:24Z,
> last pushed 14:22Z — roughly one day of public exposure, with 0 forks and
> 0 stars at the time of checking. The password must be treated as compromised
> and rotated; see `docs/F4-REMEDIATION.md` for what was done and what remains.

**Why it matters:** the password is in the object database, not just the working
tree. Deleting the line in a new commit does not remove it — anyone who clones
or forks the repo still gets it from history. Public repositories are scraped by
automated secret scanners continuously, and a credential that has been public
for a day should be assumed collected. The only real fix is rotating the
password on the MySQL server; removing it from history limits future exposure
but does not undo past exposure.

**Effort: S** to externalise (environment variable / `application-local.properties`
that is gitignored) and rotate the DB password. **M** if you also want to purge
it from history.

---

**F5 · CRITICAL · Anyone can register themselves as SUPERVISOR**
`backend/.../controller/UserController.java:22`, `.../service/UserService.java:58-60`,
`frontend/lib/screens/register_screen.dart:88-100`

`POST /api/v1/users` binds the request body straight onto the `User` entity, so
the client supplies `role`. `registerNewEmployee` only defaults it to `EMPLOYEE`
when it is null or empty — a supplied value passes through untouched. The
registration screen even offers a role dropdown containing `SUPERVISOR`.

**Why it matters:** the privilege boundary in this system is a self-declared
string. A new hire — or a stranger, given F1 — can register as a supervisor and
immediately approve their own leave, delete colleagues, and read every message.
Combined with F1 there is no boundary at all, but this bug would survive even
after authentication is added, unless the field is rejected on input.

**Effort: S** — accept a registration DTO without a `role` field and set the role
server-side.

---

**F6 · HIGH · JPA entities are bound directly from request bodies (mass assignment)**
`UserController.java:22,58`, `NewsItemController.java:23,61`,
`ShiftController.java:24,49`, `LeaveRequestController.java:25`

Every write endpoint takes `@RequestBody <Entity>`. The client therefore controls
every persisted field, including `id`, and including fields the endpoint has no
business letting them set.

**Why it matters:** beyond F5, this means the API's contract is whatever the
database schema happens to be today. Rename a column and every client breaks;
add a sensitive column and it is silently writable and readable. It also directly
violates the project's own rule in `CLAUDE.md`: *"Controllers never expose JPA
entities. DTOs only."* Only `LoginRequest` and `MessageRequest` follow it.

**Effort: M** — one request/response DTO pair per resource; mechanical but
touches all five controllers.

---

**F7 · HIGH · Every user can read every leave request; the filter is cosmetic**
`backend/.../controller/LeaveRequestController.java:48-51`,
`frontend/lib/screens/leave_requests_screen.dart:19,42-46`

The Flutter screen calls `GET /api/v1/leaves` (all requests, all employees) and
then filters to the current user *in Dart* when `!Session.isSupervisor()`.
The endpoint that would scope this server-side
(`/api/v1/leaves/users/{userId}/leaves`) exists and is never called.

**Why it matters:** leave reasons are health and family information — "surgery",
"funeral", "IVF". The data leaves the server and reaches every employee's phone;
the UI merely declines to draw it. Anyone with the app can read colleagues'
medical leave by inspecting network traffic, and no server log will show
anything unusual. The identical pattern applies to shifts
(`shifts_screen.dart:37-41` fetches all shifts for supervisors).

**Effort: S** — call the per-user endpoint for non-supervisors. Genuinely fixing
it (server decides from the authenticated principal) depends on F1.

---

### Data layer

---

**F8 · HIGH · `ddl-auto=update` is the only schema management**
`backend/src/main/resources/application.properties:10`

There is no Flyway, no Liquibase, and no SQL baseline in the repository.

**Why it matters:** Hibernate's `update` is additive-only and best-effort. It
adds columns and tables; it never drops, renames, narrows a type, or backfills.
So the schema on a machine that has been running since day one is quietly
different from the schema `update` produces on a fresh database — and the
difference is invisible until something fails in a way that reproduces on one
machine and not another. It also means there is no reviewable record of a schema
change: the entity diff is the only evidence. On a shared or production database
this same setting will happily apply a half-understood mapping change.

**Effort: M** — add Flyway, baseline the current schema, switch to
`ddl-auto=validate`.

---

**F9 · HIGH · No pagination on any collection endpoint**
`UserController.java:33`, `ShiftController.java:35`, `LeaveRequestController.java:50`,
`NewsItemController.java:34`, `MessageController.java:36,41,46,51`

Every list endpoint returns `List<T>` from an unbounded `findAll()` or derived
query. `MessageRepository` has no limit on chat history either.

**Why it matters:** response size is a function of how long the app has been in
use. A year of messages between two users is one query, one JSON array, one
allocation of the whole thing in server memory, and one parse of the whole thing
on a phone. This degrades smoothly right up until it doesn't — and the first
symptom is usually an OOM or a mobile client that freezes on open, in
production, at the worst possible time.

**Effort: M** — accept `Pageable`, return `Page<T>`; the client must change too,
which is the bulk of the work.

---

**F10 · MEDIUM · N+1 queries on every list endpoint** *(inferred — not measured)*
`LeaveRequest.java:38`, `Shift.java:37`, `Message.java:33,37`, `NewsItem.java:44`
(all `@ManyToOne` with no `fetch` attribute) consumed by
`LeaveRequestService.java:30`, `ShiftService.java:29`, `NewsItemService.java:29`,
`MessageService.java:34-47`

`@ManyToOne` defaults to `EAGER` in JPA. A `findAll()` returning N rows issues
one query for the list plus one per distinct associated `User` that is not
already in the persistence context. `Message` has two such associations, so
`GET /messages/chat` is the worst case.

I have not run this with SQL logging on, so the exact query count is inferred
from the mapping, not observed. Enabling `spring.jpa.show-sql` on a chat with
~20 messages would confirm it in about a minute.

**Why it matters:** it is invisible on the ten rows in your dev database and
linear in production. Each extra query is a network round-trip to MySQL, so a
100-message chat becomes a visibly slow screen, and the cause is in the entity
mapping rather than anywhere near the code that feels slow.

**Effort: S** — `fetch = FetchType.LAZY` on the associations plus an explicit
`JOIN FETCH` (or an `@EntityGraph`) on the queries that need the user.

---

**F11 · MEDIUM · Write operations run without an explicit transaction boundary**
`ShiftService.java:22-58`, `LeaveRequestService.java:22-51`, `MessageService.java:21-64`,
`NewsItemService.java:22-61` (only `UserService.deleteUser:86` is annotated)

Each repository call gets its own transaction, so a service method that does
several is several transactions.

**Why it matters:** the read-modify-write methods — `updateShift`,
`updateNewsItem`, `updateLeaveRequest` — load an entity in one transaction and
save it in another. Between those two, another request can change the same row,
and the second write silently overwrites the first with no error. Two supervisors
editing the same shift is exactly the scenario this app is for.

**Effort: S** — `@Transactional` on the service write methods.

---

**F12 · MEDIUM · `deleteUser` cascades by hand across four repositories**
`backend/.../service/UserService.java:86-96`, and the `@Modifying` /
`deleteBy...` methods in `MessageRepository:25-31`, `ShiftRepository:20-22`,
`LeaveRequestRepository:19-21`

Deleting a user runs four bulk deletes and then deletes the user. Note also that
the repositories use `jakarta.transaction.Transactional` while `UserServiceTest`
uses `org.springframework.transaction.annotation.Transactional` — two different
annotations for the same concept in one codebase.

**Why it matters:** the list of things to delete lives in a method body, not in
the schema. The next entity that references `User` will compile fine, pass
tests, and then fail at runtime on a foreign-key violation the first time
someone deletes an employee — which the controller reports as a bare 500
(`UserController.java:74`). Bulk `@Modifying` deletes also bypass the persistence
context, so any entity already loaded in the same transaction is now stale.

**Effort: M** — express the relationship in the schema (`ON DELETE` / cascade /
`orphanRemoval`), or at minimum make the deletion order a documented,
tested invariant.

---

**F13 · LOW · No indexes declared, and a misspelled column name**
`Message.java:38` (`reciever_id`), and all five entities (no `@Index`)

Every lookup in this app filters on a foreign key or sorts by a timestamp —
`findByReceiverIdOrderByTimestampDesc`, `findByUserIdAndDateBetweenOrderByDateAsc`,
`findAllByOrderByCreatedAtDesc` — and none of those columns is indexed. MySQL
does index FK columns automatically for InnoDB constraints, so the FK case is
partly covered **[inferred]**; the sort columns (`timestamp`, `createdAt`,
`date`) are not.

**Why it matters:** low today because the tables are small. It becomes a filesort
on every inbox load once messages accumulate. The column typo matters
separately: `reciever_id` is now baked into the database by `ddl-auto`, so
renaming it later needs a migration (see F8) — it is cheapest to fix now.

**Effort: S**

---

### API design and error handling

---

**F14 · HIGH · Every exception becomes a 404**
`LeaveRequestController.java:29-31,40-42,62-64,73-75`,
`MessageController.java:29-31,58-60,68-70`,
`NewsItemController.java:27-29,49-51,64-66,74-76`,
`ShiftController.java:28-30,43-45,53-55,63-65,76-78`,
`UserController.java:62-64`

The pattern is `catch (RuntimeException e)` — or, in `MessageController` and
`NewsItemController`, the broader `catch (Exception e)` — returning
`HttpStatus.NOT_FOUND` with `e.getMessage()` as a bare string body. There is no
`@ControllerAdvice` anywhere.

**Why it matters:** three distinct things collapse into one status code. A
database outage, a null-pointer bug, and a genuinely missing record all return
404 "not found". The client cannot distinguish "this leave request does not
exist" from "the server is broken" — so it cannot decide whether retrying makes
sense, and monitoring cannot alert on real failures because they do not look
like errors. `NewsItemService.createNewsItem:23` dereferences
`newsItem.getAuthor().getId()` with no null check; omit `author` from the JSON
and the resulting NPE is reported to the client as 404.

The same `try/catch` block is also copy-pasted roughly 18 times, which is what a
missing `@ControllerAdvice` looks like.

**Effort: M** — a typed exception (`ResourceNotFoundException`) plus one
`@ControllerAdvice` returning a consistent error body; then delete the 18 blocks.

---

**F15 · MEDIUM · No input validation anywhere**
`pom.xml` (no `spring-boot-starter-validation`); no `@Valid`, `@NotNull`,
`@NotBlank`, `@Email` or `@Size` in any controller, DTO or entity

The only guards are `@Column(nullable = false)` — enforced by the database, at
the very end of the request — and the duplicate-email check in
`UserService.registerNewEmployee:51`.

**Why it matters:** a leave request with `endDate` before `startDate` is
accepted. A blank name, a malformed email, a 10,000-character message, a shift
ending before it starts — all accepted, all persisted. The failures that *do*
occur surface as constraint-violation stack traces converted into a 404 (F14),
rather than a message telling the user which field was wrong. The Flutter client
does validate (`login_screen.dart:58-62`, `register_screen.dart:21-36`), which
means the rules exist but live only where the user can bypass them.

**Effort: S** — add the starter, annotate the DTOs, add `@Valid`.

---

**F16 · MEDIUM · Inconsistent API shapes and response types**

- `ResponseEntity<?>` on 17 of 25 handlers — the success and error bodies have
  different types, so nothing is checked at compile time and no schema can be
  generated.
- `DELETE /messages/{id}` returns the plain string `"Message deleted successfully"`
  (`MessageController.java:67`) while every other delete returns 204.
- `POST /users/login` returns a Greek-language error string
  (`UserController.java:85`) — user-facing copy hard-coded in a controller.
- `DELETE /users/{id}` returns 500 for a missing user (`UserController.java:74`),
  where the other controllers return 404.
- `GET /api/v1/leaves/users/{userId}/leaves` (`LeaveRequestController.java:35`)
  repeats "leaves" and nests under the wrong base path.
- `ShiftController` is mapped at `/api/v1/` and serves two unrelated resources
  (`ShiftController.java:14`); `UserController`'s base path
  (`UserController.java:13`) omits its leading slash while the other four have one.

**Why it matters:** each is minor, but together they mean every client call
needs its own special-case handling, and a generated API client or OpenAPI
document is not possible. It is also the kind of inconsistency that quietly
sets the convention for the next twenty endpoints.

**Effort: M**

---

**F17 · LOW · Broken URL in a dead client method**
`frontend/lib/services/api_service.dart:197`

`getMyShifts()` requests `/shifts/user/$userId`; the backend route is
`/shifts/users/{userId}` (`ShiftController.java:38`) — singular vs plural. The
method has no callers (`ShiftsScreen` uses `getFilteredShifts` /
`getAllShifts`), so nothing currently breaks.

**Why it matters:** it is a landmine, not a bug. Whoever wires this method up
gets a 404, and the `throw Exception("Αποτυχία φόρτωσης βαρδιών")` on the next
line will point them at "the server", not at a one-character typo in the URL.

**Effort: S** — fix the path or delete the method.

---

### Layering and code structure

---

**F18 · MEDIUM · `UserService` mixes constructor and field injection**
`backend/.../service/UserService.java:18-32`

Four `@Autowired` fields *and* a constructor that sets only `userRepository`
(injecting it twice — once via the constructor, once via the field).

**Why it matters:** the class cannot be constructed correctly in a plain unit
test: `new UserService(userRepo)` compiles and leaves three repositories null,
so the object fails at runtime instead of at the call site. That is very likely
part of why `UserServiceTest` is a full `@SpringBootTest` against real MySQL
rather than a fast Mockito unit test — field injection quietly forces the slow
kind of test. None of the fields are `final`, so the object is also mutable
after construction.

This is worth naming as a pattern: constructor injection makes dependencies a
compile-time contract; field injection hides them. The other four services get
this right — `UserService` is the outlier.

**Effort: S** — one constructor taking all four repositories, all fields `final`,
drop the `@Autowired`.

---

**F19 · LOW · DTOs are split across two packages, and `model` holds a non-entity**
`backend/.../model/MessageRequest.java` vs `backend/.../dto/LoginRequest.java`

`MessageRequest` is a DTO (its own Javadoc says so) living in the entity package.
`dto/` contains exactly one class.

**Why it matters:** "where do DTOs go" currently has two answers, so the next
one lands in whichever package the author saw last. Cheap to settle now, tedious
after twenty classes exist.

**Effort: S**

---

**F20 · LOW · Dead code, unused imports, and a debug artifact left in a handler**
`UserController.java:73` (`e.printStackTrace()` plus a Greek debugging comment,
"Θα δεις το πραγματικό λάθος στο IntelliJ"),
`LeaveRequestService.java:5` (imports `User`, never referenced in the file),
`frontend/lib/screens/profile_screen.dart:143` (`_buildStatColumn`, never called),
`frontend/lib/screens/employee_list_screen.dart:2` (imports `session.dart`;
`Session` is not referenced in that file)

**Why it matters:** `printStackTrace` in a request handler writes to stdout
instead of the logger, so the stack trace is absent from structured logs and
from anything that aggregates them. The rest is ordinary drift.

**Effort: S**

---

### Testing

---

**F21 · HIGH · The Flutter test suite does not compile**
`frontend/test/widget_test.dart:16`

The file is the untouched Flutter template. It calls `const MyApp()`, but
`MyApp` (`frontend/lib/main.dart:8`) declares no constructor, so its implicit
default constructor is non-const — `const MyApp()` is a compile-time error
**[inferred: read from source; I did not run `flutter test`]**. Even if it
compiled, it asserts on a counter widget and a `+` button that do not exist in
this app.

**Why it matters:** `flutter test` fails on a clean checkout, which trains
everyone to ignore the result. A test suite that is known-red provides no signal
— the next real failure looks exactly like this one.

**Effort: S** — replace it with a test that pumps `LoginScreen` and asserts the
email and password fields render.

---

**F22 · HIGH · 25 endpoints, 0 endpoint tests**
`backend/src/test/java/.../` (2 files)

`CLAUDE.md` states: *"Every new endpoint needs at least one test."* Current
coverage is `UserService` and a context-load smoke test. Four of five services
and all 25 endpoints are untested — including status-code behaviour, JSON shape,
and the role checks that F1 shows do not exist.

**Why it matters:** the F14 "everything is a 404" behaviour and the F3 password
leak are both the kind of thing a single `@WebMvcTest` asserting on the response
body would have caught on day one. Without endpoint tests, the API contract is
whatever the code currently does, and any refactor is a rewrite.

**Effort: L** for full coverage; **M** for a meaningful slice (`@WebMvcTest` per
controller, happy path + not-found).

---

**F23 · MEDIUM · Tests run against the developer's real MySQL**
`backend/src/test/java/.../UserServiceTest.java:14-15`; no `src/test/resources`

`@SpringBootTest` with no test profile picks up the production
`application.properties`, so the suite needs a live MySQL at `localhost:3306`
with the committed credentials (F4). `@Transactional` rolls each test back, which
is the one thing keeping this from writing to the dev database permanently.

**Why it matters:** the tests do not run on a machine that has not been set up
by hand, which means they do not run in CI, which means they do not run. They
also cannot run in parallel or on two branches at once. `CLAUDE.md` already
names Testcontainers as the planned fix — that is the right instinct; an
in-memory H2 profile is the cheaper interim step, at the cost of not testing
against real MySQL behaviour.

Two smaller points in the same file: `assertTrue(users.size() > 0)`
(`UserServiceTest.java:36`) passes on any non-empty table including leftover
rows, and the assertion messages are in Greek while the rest of the codebase's
comments are mixed Greek and English.

**Effort: M**

---

### Flutter architecture and state

---

**F24 · MEDIUM · Session is a mutable global with no persistence**
`frontend/lib/utils/session.dart:3-10`, used in 11 files

`Session.currentUser` is a `static User?`. Every screen reads it directly, and
`ApiService` reads it too (`api_service.dart:112,156,196,250,262,276`) — so the
service layer depends on global UI state rather than receiving what it needs.

**Why it matters:**
- **It is force-unwrapped everywhere** (`Session.currentUser!` at
  `api_service.dart:112,156,196,262,276`, `messages_list_screen.dart:27,54,66`,
  `chat_screen.dart:42`, `profile_screen.dart:16`). Any path that reaches those
  screens without a login crashes the app rather than redirecting.
- **It does not survive a restart.** Close the app, reopen it, log in again —
  every time. There is no `shared_preferences` or secure storage in the project.
- **Nothing rebuilds when it changes.** `ApiService.updateUser:184-186` mutates
  `Session.currentUser` fields directly; screens only update because
  `ProfileScreen` calls an empty `setState(() {})` afterwards
  (`profile_screen.dart:59`) to force a repaint. That is the symptom the
  state-management package named in `CLAUDE.md` would remove.
- **Logout is inconsistent**: `HomeScreen`'s logout button is
  `Navigator.pop(context)` (`home_screen.dart:22`) and never clears the session,
  while `ProfileScreen`'s (`profile_screen.dart:92`) does. Popping back to login
  leaves the previous user fully authenticated in memory.

**Effort: M** — introduce a real state container (Riverpod, per the project's own
stated intent) and persist the session.

---

**F25 · MEDIUM · `BuildContext` used across async gaps**
`login_screen.dart:140,144,148,153,160`, `register_screen.dart:55,59`,
`profile_screen.dart:62-66`, `employee_details_screen.dart:79-88`,
`leave_requests_screen.dart:83,135`, `news_screen.dart:194,222`

The pattern is `await someCall(); ScaffoldMessenger.of(context)...` with no
`if (!mounted) return;` guard. `flutter_lints` 5.0.0 is configured
(`analysis_options.yaml:11`) and flags this as `use_build_context_synchronously`
**[inferred: I did not run `flutter analyze`]**.

**Why it matters:** if the user navigates back while the request is in flight,
the widget is disposed and the `context` is dead — the app throws instead of
showing the snackbar. It is intermittent and network-timing dependent, which
makes it the kind of crash that reproduces only for users.
`employee_details_screen.dart:79-82` is the sharpest case: two `Navigator.pop`
calls followed by `ScaffoldMessenger.of(context)` on a context that has just
been popped twice.

`ChatScreen` gets this right (`chat_screen.dart:47` checks `mounted`, and
`dispose` cancels the polling timer) — so the correct pattern is already in the
codebase and just needs applying consistently.

**Effort: S** — add `if (!mounted) return;` after each await that is followed by
a context use.

---

**F26 · MEDIUM · Debug `print` statements ship in the app, including response bodies**
`frontend/lib/services/api_service.dart:53,98,292,300,305,306,313,331`,
`login_screen.dart:159`, `chat_screen.dart:53`

`api_service.dart:306` is `print("Response Body: ${response.body}")` on the
inbox call. `api_service.dart:53` prints the full delete URL.

**Why it matters:** `print` output goes to the device log, which on Android is
readable by tooling and persists after the app closes. Given F3, printing raw
response bodies means user records — passwords included, on any endpoint that
returns a `User` — are written to a log that outlives the session. It is also a
lint violation (`avoid_print`) that the project has left enabled.

**Effort: S**

---

**F27 · LOW · Backend base URL is hard-coded to the Android emulator loopback**
`frontend/lib/services/api_service.dart:12` — `http://10.0.2.2:8080/api/v1`

`10.0.2.2` is the Android emulator's alias for the host machine. The app cannot
run on a physical device, on iOS simulator, or against any deployed backend
without editing source. It is also `http://`, so every request — including
login — is in cleartext.

**Why it matters:** it works today because there is exactly one deployment
target: this laptop. The first demo on a real phone requires a code change and
a rebuild.

**Effort: S** — a `--dart-define` build-time constant, or a small config class.

---

**F28 · LOW · Chat polls every 3 seconds and marks messages read one HTTP call at a time**
`frontend/lib/screens/chat_screen.dart:27,41-45`

A `Timer.periodic` refetches the entire chat history every 3 seconds. Each
refetch loops over the messages and issues a separate `PUT .../read` for each
unread one.

**Why it matters:** opening a chat with 15 unread messages fires 15 sequential
HTTP requests. The 3-second poll means an idle open chat is 20 full-history
fetches per minute, per user, forever — with no pagination (F9) that is the
entire conversation each time. On mobile this is a measurable battery and data
cost. Credit where due: the timer *is* cancelled in `dispose`
(`chat_screen.dart:32`), which is the mistake most often made here.

**Effort: M** — a bulk mark-as-read endpoint, and either a longer poll interval
or fetching only messages after the last known id.

---

**F29 · LOW · Model `fromJson` methods assume every field is present**
`user_model.dart:20-26`, `shift_model.dart:20-28`, `message_model.dart:20-29`,
`news_model.dart:24-34`, `leave_request_model.dart:20-28`

Fields are read as `json['x']` into non-nullable Dart types with no null check —
`User.fromJson` requires `name`, `email`, `password` and `role` all non-null;
`Message.fromJson` dereferences `json['sender']['id']` unconditionally.

**Why it matters:** any backend response missing a field — a `NewsItem` with a
null `author`, which the schema explicitly permits (`NewsItem.java:44-45`) —
throws a type error deep inside a `FutureBuilder`, and the user sees a raw Dart
exception string in the error state
(e.g. `employee_list_screen.dart:34`, `Text("Σφάλμα: ${snapshot.error}")`).
`NewsItem.toJson` (`news_model.dart:37-47`) also emits `author` and `DateTime`
objects rather than serializable maps/strings; it appears unused, since
`postNews` builds its own body (`api_service.dart:108-116`).

**Effort: S**

---

**F30 · LOW · No shift-overlap or duplicate constraint** *(inferred from absence)*
`ShiftService.java:22-26`, `Shift.java` (no `@UniqueConstraint`)

`createShift` saves whatever it is given. Nothing prevents assigning the same
employee two overlapping shifts on the same day, in the database or in the
service.

**Why it matters:** for a shift-management app this is the domain's central
invariant, and it is currently enforced nowhere. I am flagging it as an
observation about what exists, not proposing a feature — the decision about what
the rule should be is yours.

**Effort: M**

---

### Finding summary

| Severity | Count | IDs |
|---|---|---|
| CRITICAL | 5 | F1–F5 |
| HIGH | 7 | F6, F7, F8, F9, F14, F21, F22 |
| MEDIUM | 10 | F10, F11, F12, F15, F16, F18, F23, F24, F25, F26 |
| LOW | 8 | F13, F17, F19, F20, F27, F28, F29, F30 |

The five CRITICALs are not five separate problems. F1 (no auth) is the root;
F2/F3 (plaintext passwords, in the DB and on the wire) and F5 (self-assigned
roles) are what make F1 unrecoverable rather than merely open. F4 (committed
credentials) is independent and is the only one with a deadline attached — the
password should be rotated on the MySQL server regardless of what else happens,
because it is already in git history.

---

## Part 3 — Three things this codebase does well

These are genuine, not consolation prizes.

**1. The service layer is properly separated, and four of five services inject
correctly.**
`ShiftService`, `MessageService`, `NewsItemService` and `LeaveRequestService` all
use constructor injection with `final` fields, and all business logic —
existence checks, status defaults, the read-modify-write in
`ShiftService.updateShift:36-46` — lives in the service, not the controller and
not the repository. Controllers only translate HTTP to method calls. No
controller touches a repository directly; no `EntityManager` or raw SQL appears
outside the repository interfaces. That is the layering rule in `CLAUDE.md` being
followed in 4 of 5 places, and it is the structural decision that makes every
other finding in this report fixable in one layer at a time. `UserService` (F18)
is the exception, and it is visibly the oldest file.

**2. Filtering and sorting are pushed into the database, not done in memory.**
`findByUserIdAndDateBetweenOrderByDateAsc` (`ShiftRepository:17`),
`findAllByOrderByCreatedAtDesc` (`NewsItemRepository:13`),
`findByTypeOrderByCreatedAtDesc`, `findByReceiverIdAndIsReadFalse`
(`MessageRepository:23`) — the schedule endpoint queries a date range in SQL
rather than fetching everything and filtering in Java. This is a real
distinction, and the more common beginner version is `findAll()` followed by a
stream filter. The naming is unwieldy in one case
(`findBySenderIdAndReceiverIdOrSenderIdAndReceiverIdOrderByTimestampAsc`) but the
instinct behind it is correct: let the database do database work. That instinct
is also what makes F7 and F9 straightforward to fix — the query methods you need
mostly already exist and are simply not being called.

**3. Repository lookups use `Optional` with `orElseThrow`, consistently, in
every service.**
`UserService:40,45`, `ShiftService:37`, `MessageService:52`, `NewsItemService:41,46`,
`LeaveRequestService:47`. Not one place in the backend returns or dereferences a
possibly-null entity from a lookup. The comment at `UserRepository:12` shows this
was a deliberate choice rather than an accident of the IDE's autocomplete. The
resulting exceptions are handled too bluntly (F14 turns them all into 404s), but
the alternative — silent nulls propagating into NPEs several frames away — is a
much harder class of bug, and this codebase does not have it.

**A fourth, worth naming:** `ChatScreen` (`frontend/lib/screens/chat_screen.dart`)
cancels its `Timer` and disposes its `TextEditingController` in `dispose()`, and
checks `mounted` before `setState` after an await. Those are the exact leaks
Flutter beginners ship, and this file avoids all three — which is why F25 is
worth fixing elsewhere in the app: the correct pattern is already here to copy.

---

## Appendix — what was not assessed

- Nothing was compiled or executed. Test results quoted in §1.5 come from stale
  surefire XML in `backend/target/`, not from a run performed for this audit.
- `flutter analyze` was not run; lint claims (F25, F26) are read from the source
  against the configured `flutter_lints` 5.0.0 rule set.
- The generated platform folders (`android/`, `ios/`, `linux/`, `macos/`,
  `windows/`, `web/`) were not reviewed beyond confirming they are the Flutter
  template and that no signing keys or `local.properties` are tracked by git.
- No penetration testing, dependency CVE scanning, or database inspection was
  performed. F1–F5 are read directly from source, not demonstrated against a
  running instance.
