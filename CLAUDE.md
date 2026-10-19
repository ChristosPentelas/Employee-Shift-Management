# Project: Employee Shift Management

## Stack
- Backend: Spring Boot 4.x, Java 21, MySQL 8, Maven
- Frontend: Flutter 3.x, Dart, Riverpod
- Testing: JUnit 5, Mockito, Testcontainers (MySQL)

Backend integration tests start a throwaway MySQL 8.0.44 container, so
**Docker must be running** before `mvnw test`. They do not touch the local
MySQL server and need no credentials.

## Working agreement — IMPORTANT
The owner of this repo is a junior developer using this project to learn.

1. Before editing, state the plan and wait for approval.
2. Keep changes small — one concept per change set. Never refactor
   multiple layers in a single pass.
3. After every change, explain WHY, not just what. Name the pattern
   or principle involved.
4. When there was a real alternative, name it and say why you didn't
   pick it.
5. Never introduce a new dependency without asking first.
6. Never weaken or delete a test to make it pass.
7. Point out beginner pitfalls in the existing code as you encounter them.
8. Who writes the production code depends on the word `kayak`:
   - **Without `kayak`** in the owner's message: Claude writes the production
     code, after the plan from rule 1 is approved.
   - **With `kayak`**: the owner writes the production code. Plan together
     first: give a todo with every place to edit, the pitfalls, and what to
     read. Do not write the implementation unless asked to for a specific
     part. Claude reviews the owner's diff.
   The word counts for the whole task it starts, not only for that message.
   Either way, Claude writes the tests and the `docs/BACKLOG.md` changes.

## Conventions
- Controllers never expose JPA entities. DTOs only.
- Business logic lives in services, not controllers or repositories.
- Every new endpoint needs at least one test.
- Conventional Commits.
