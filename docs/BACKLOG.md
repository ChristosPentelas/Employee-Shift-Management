# Backlog — things noticed while working

A living list of problems and "could be written better" spots found during
day-to-day work. `AUDIT.md` is a dated snapshot and is not edited; this file is
the opposite — add to it whenever something is noticed, and mark items done
when they are fixed.

Rules:

- One entry per problem. Give it the next `B` number; numbers are never reused.
- If it overlaps an audit finding, say which (`F14`) instead of repeating it.
- When fixed, move it to **Done** with the commit hash. Don't delete it — the
  history of what went wrong is part of the learning.

Severity uses the audit's scale: CRITICAL · HIGH · MEDIUM · LOW.

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

**B4 · LOW · No record of which audit findings are closed** — found 2026-09-10
Where: `AUDIT.md` (by design a snapshot) and the commit messages, which say
things like "closes F3".
Why it matters: to know whether F6 is fixed you have to read git history.
Fix idea: add a status table here (ID · status · commit), filled in from the
commit messages.

---

## Done

_Nothing yet._
