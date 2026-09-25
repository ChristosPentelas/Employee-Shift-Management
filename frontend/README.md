# employee_shift_management_ui

A new Flutter project.

## Pointing the app at the backend

The app reads the backend's address from `API_BASE_URL` when it is built. The
address ends in `/api/v1`, with no trailing slash.

| Where the app runs | Command |
|---|---|
| Android emulator | `flutter run` (the default, `http://10.0.2.2:8080/api/v1`, is the emulator's name for your PC) |
| iOS simulator | `flutter run --dart-define=API_BASE_URL=http://localhost:8080/api/v1` |
| Physical phone on your Wi-Fi | `flutter run --dart-define=API_BASE_URL=http://<your PC's IP>:8080/api/v1` |

For a physical phone: find your PC's IP with `ipconfig` (IPv4 Address), and
allow inbound TCP port 8080 through the Windows firewall. The backend already
listens on every network interface.

The value is compiled into the app: after changing it, stop and start
`flutter run` again. A hot reload or hot restart keeps the old address.

A **release** build refuses to start unless the address begins with
`https://`, because every request carries the login token. Note that
`flutter build apk` builds release by default: to try the app on a phone
against your PC over `http://`, use `flutter build apk --debug`.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
