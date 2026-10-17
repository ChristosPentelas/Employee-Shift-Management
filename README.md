# Employee Shift Management

A mobile app for planning a company's work shifts. Supervisors set up the
staff accounts, plan everyone's shifts and approve leave. Employees check
their schedule on a calendar, request time off, read company news and chat
with colleagues.

The app's user interface is in Greek.

<p align="center">
  <img src="docs/screenshots/home.png" alt="The dashboard after logging in" width="320">
</p>

## Features

**Employees**

- See their own shifts on a monthly calendar
- Request leave and follow whether it is approved
- Read company news: announcements, goals and tasks
- Send private messages to colleagues
- Edit their profile and change their password

**Supervisors** can do all of the above, and also:

- Create employee accounts (there is no public sign-up)
- Create, change and delete shifts for anyone
- Approve or reject leave requests
- Post, edit and delete news

**Security**

- Login with a JWT bearer token that expires after 8 hours
- An account locks for 15 minutes after 5 wrong passwords
- Every request is checked on the server: an employee can only see their own
  shifts, leave requests and messages

## Tech stack

| Part | Technology |
|---|---|
| Backend | Java 21, Spring Boot 4.0 (Web MVC, Security, Data JPA, Validation) |
| Authentication | Spring Security OAuth2 Resource Server (JWT), BCrypt passwords |
| Database | MySQL 8, schema managed by Flyway migrations |
| Frontend | Flutter 3 / Dart 3.7, Riverpod, `http`, `table_calendar`, `flutter_secure_storage` |
| Tests | JUnit 5, Mockito, Testcontainers (a throwaway MySQL in Docker) |
| Build | Maven (wrapper included) |

## Project layout

```
backend/    Spring Boot REST API under /api/v1
frontend/   Flutter app
docs/       audit, backlog and design notes
```

## How to run it

### Prerequisites

- JDK 21
- MySQL 8, running locally
- [Flutter SDK](https://docs.flutter.dev/get-started/install) 3.29 or newer,
  plus an Android emulator, iOS simulator or phone
- Docker, only if you want to run the backend tests

### 1. Create the database

```sql
CREATE DATABASE employee_shift_db;
```

The tables are created by Flyway the first time the backend starts.

### 2. Configure the backend

Credentials and secrets are kept out of git. Copy the template and fill it in:

```bash
cd backend
cp application-local.properties.example application-local.properties
```

In `application-local.properties`, set:

- `spring.datasource.username` / `spring.datasource.password`: your MySQL login
- `app.first-supervisor.*`: the first supervisor account, created on startup
  while the database has no supervisor yet
- `app.jwt.secret`: a random Base64 key of at least 32 bytes, used to sign the
  login tokens. The backend refuses to start without it. Generate one with:

  ```bash
  # Git Bash / macOS / Linux
  openssl rand -base64 32
  ```

  ```powershell
  # PowerShell
  $b = New-Object byte[] 32; [Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($b); [Convert]::ToBase64String($b)
  ```

### 3. Start the backend

```bash
cd backend
./mvnw spring-boot:run       # Windows: .\mvnw.cmd spring-boot:run
```

The API listens on `http://localhost:8080/api/v1`.

### 4. Start the app

```bash
cd frontend
flutter pub get
flutter run
```

By default the app talks to `http://10.0.2.2:8080/api/v1`, which is how the
Android emulator reaches your computer. For the iOS simulator or a real phone,
pass the address with `--dart-define=API_BASE_URL=...`; see
[frontend/README.md](frontend/README.md) for the exact commands.

### 5. Log in

Log in with the email and password you set in `app.first-supervisor.*`, and
change that password from the profile screen. Then add employees from the
employees screen.

## Running the tests

Start Docker first: the integration tests run against a temporary MySQL
8.0.44 container, not your local database, and need no credentials.

```bash
cd backend
./mvnw test                  # Windows: .\mvnw.cmd test
```

## Known limitations

- The backend serves plain HTTP for now. A release build of the app only
  accepts an `https://` address, so release builds need the backend behind
  HTTPS first. For trying it on a phone, use `flutter build apk --debug`.
- One company per installation.

Open issues and planned work are tracked in [docs/BACKLOG.md](docs/BACKLOG.md).
