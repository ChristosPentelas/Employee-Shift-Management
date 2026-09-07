# Project: Employee Shift Management

## Stack
- Backend: Spring Boot 3.x, Java 21, PostgreSQL, Maven
- Frontend: Flutter 3.x, Dart, Riverpod
- Testing: JUnit 5, Mockito, Testcontainers

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

## Conventions
- Controllers never expose JPA entities. DTOs only.
- Business logic lives in services, not controllers or repositories.
- Every new endpoint needs at least one test.
- Conventional Commits.
