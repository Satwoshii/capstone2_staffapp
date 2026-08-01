# Syswatch Admin App

## Overview

The **Syswatch Admin App** is the management application for the Syswatch intranet system.

The former ITSO and Admin roles have been merged into one role:

```text
Admin
```

The Admin App connects to the local PHP/MariaDB server and does not use Firebase or Firestore.

---

## Main Features

### Admin authentication

- Admin email and password login.
- Authentication through the local PHP API.
- Local API token storage.
- Session expiration handling.
- Sign-out and token clearing.
- Configurable server address.

### Account management

- Create Student accounts.
- Create additional Admin accounts.
- View accounts.
- Search and filter accounts.
- Enable or disable accounts.
- Reset passwords.
- Prevent duplicate email.
- Prevent duplicate Student ID.
- Keep Student accounts centralized in MariaDB.

### Room management

- Create rooms.
- View room records.
- Update room details.
- Set room capacity.
- Enable or disable rooms.
- Associate workstations with rooms.

### PC health

- View registered workstations.
- View latest workstation heartbeat.
- View current hardware/peripheral status.
- View issue severity.
- View online/offline state.
- View room and PC assignment.

### Repairs and maintenance

- View unresolved fault reports.
- Mark or update repair status.
- Add maintenance notes.
- Record repair actions.
- View maintenance history.
- Track resolved and unresolved problems.

### Last known user

- View the latest student associated with a workstation.
- View room and PC.
- View login/session timestamps.
- Help identify who last used a PC before a fault.

### Reports

- View fault reports.
- View health reports.
- View student-reported issues.
- View severity and status.
- View timestamps and workstation information.

### Audit and centralized records

- Central MariaDB storage.
- API access tokens.
- Login logs.
- Audit records.
- Workstation records.
- Room records.
- Account records.

---

## Admin Permissions

Admin can:

- Use every Staff App feature.
- Create Student and Admin accounts.
- Configure rooms.
- View reports.
- Manage repairs.
- View the last known student.
- Configure Student workstations.
- Enable or disable accounts.
- Reset passwords.

There is no separate ITSO login in the current version.

---

## Requirements

### Development

- Flutter SDK
- Windows desktop support
- Visual Studio with Desktop development with C++
- `path_provider`
- `crypto`
- Working Syswatch PHP/MariaDB server

### Runtime

- Windows 10 or Windows 11
- Connection to the same laboratory LAN as the server
- Valid Admin account
- Correct server address

---

## Installation

### 1. Install packages

From the Admin App project:

```powershell
flutter clean
flutter pub get
flutter analyze
```

### 2. Run in development

```powershell
flutter run -d windows
```

### 3. Build the release version

```powershell
flutter build windows --release
```

Copy the complete Release folder when deploying to another computer.

---

## Server Setup

Copy the PHP API folder to:

```text
C:\xampp\htdocs\syswatch_api
```

Start:

- Apache
- MySQL/MariaDB

Import the database schema and required upgrades into:

```text
syswatch_intranet
```

Test:

```text
http://127.0.0.1/syswatch_api/health.php
```

Expected response:

```json
{
  "success": true,
  "status": "online",
  "database": "online"
}
```

---

## Configure the Server Address

### Admin App and XAMPP on the same computer

```text
http://127.0.0.1/syswatch_api
```

### Admin App on another computer

```text
http://192.168.1.10/syswatch_api
```

Use the actual IPv4 address of the server computer.

On the login screen:

1. Open **Server Settings**.
2. Enter the server address.
3. Select **Test Connection**.
4. Save the address.
5. Sign in.

---

## First Admin Account

The first Admin account may be created using the command-line tool:

```powershell
C:\xampp\php\php.exe C:\xampp\htdocs\syswatch_api\tools\create_account.php --role=admin --email=admin@syswatch.local --name="Syswatch Admin" --password="Admin12345"
```

Change the example password before deployment.

After the first Admin can log in, additional Student and Admin accounts should be created through the Admin App.

---

## Admin Login Tutorial

1. Start Apache and MariaDB on the server.
2. Open the Admin App.
3. Verify the server address.
4. Enter the Admin email.
5. Enter the password.
6. Select **Login**.
7. The app saves a local API token for the session.

If the app reports that a user access token is required:

1. Sign out.
2. Close the app.
3. Restart Apache.
4. Reopen the app.
5. Sign in again.

---

## Create a Student Account

1. Open **Accounts**.
2. Select **Add Account**.
3. Choose `Student`.
4. Enter:
   - Display name
   - Student ID
   - Email
   - Temporary password
   - Active status
5. Save the account.
6. Confirm that it appears in the account list.

The Student PC apps can then download active student accounts for SQLite offline authentication.

---

## Create an Admin Account

1. Open **Accounts**.
2. Select **Add Account**.
3. Choose `Admin`.
4. Enter:
   - Display name
   - Email
   - Password
   - Active status
5. Save.

Only trusted laboratory personnel should receive Admin accounts.

---

## Disable or Enable an Account

1. Open **Accounts**.
2. Find the account.
3. Open the account actions.
4. Select **Disable** or **Enable**.
5. Confirm.

A disabled account should no longer authenticate through the local server.

Student PCs should refresh cached accounts when connected so disabled status is reflected offline as soon as possible.

---

## Reset a Password

1. Open **Accounts**.
2. Select the user.
3. Choose **Reset Password**.
4. Enter the new temporary password.
5. Save.
6. Inform the user securely.

Passwords must never be stored or shared as plain text in documentation.

---

## Manage Rooms

1. Open **Rooms**.
2. Select **Add Room**.
3. Enter the room name or number.
4. Set capacity and active status.
5. Save.

Example:

```text
Room: 706
Capacity: 40
Status: Active
```

Student PCs use the room together with a unique PC ID.

---

## View PC Health

1. Open **PC Health**.
2. Select a room or workstation.
3. Review:
   - Workstation status
   - Last heartbeat
   - Keyboard
   - Mouse
   - Monitor
   - Ethernet
   - CPU
   - RAM
   - Disk/storage
   - Severity
4. Open the workstation details for more information.

A workstation may appear offline when it has not sent a recent heartbeat.

---

## Repair Workflow

1. Open **Repairs**.
2. Select an unresolved fault.
3. Review the workstation and issue.
4. Add a repair note.
5. Update the status.
6. Mark it resolved after verification.
7. Confirm that a maintenance record was created.

---

## Last Known User Tutorial

1. Open **Last Known User**.
2. Search by room or PC.
3. Review:
   - Student name
   - Student ID
   - Room
   - PC ID
   - Login time
   - Last session information

This feature helps identify the student who last used a workstation before a reported problem.

---

## Reports Tutorial

1. Open **Reports**.
2. Filter by room, PC, severity, status, or date.
3. Open a report.
4. Review the issue details.
5. Use the repair section when action is required.

---

## Troubleshooting

### `setState() callback argument returned a Future`

The fixed version performs asynchronous API work outside `setState()` and then updates state synchronously.

Do not write:

```dart
setState(() async {
  await loadData();
});
```

Use:

```dart
final data = await loadData();

if (!mounted) return;

setState(() {
  records = data;
});
```

### `A user access token is required`

Check:

- The Admin logged in successfully.
- The saved token exists.
- Apache was restarted after updating PHP.
- The updated `bootstrap.php` and `.htaccess` are installed.
- Sign out and sign in again.

### Cannot load screens

Open:

```text
http://SERVER_IP/syswatch_api/health.php
```

If it fails, check Apache, MariaDB, firewall, and server address.

### Another PC cannot use `localhost`

Other computers must use the server's LAN IP:

```text
http://192.168.1.10/syswatch_api
```

### `path_provider` import error

Ensure `pubspec.yaml` contains:

```yaml
path_provider: ^2.1.5
```

Then run:

```powershell
flutter clean
flutter pub get
flutter analyze
```

### Firebase references remain

Search:

```powershell
Get-ChildItem .\lib -Recurse -File |
Select-String -Pattern "firebase|firestore|FirebaseAuth|FirebaseFirestore"
```

The intranet version should not contain active Firebase imports.

---

## Recommended `pubspec.yaml`

```yaml
name: staff_admin_app
description: Syswatch intranet Admin management application.
publish_to: 'none'
version: 2.3.2+1

environment:
  sdk: ^3.5.0

dependencies:
  flutter:
    sdk: flutter

  path_provider: ^2.1.5
  crypto: ^3.0.6

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^5.0.0

flutter:
  uses-material-design: true
```

---

## Important Notes

- Student self-registration is intentionally disabled.
- Firebase data is not copied automatically.
- The API and MariaDB database must be backed up.
- The Admin App should only be used on trusted computers.
- Use one central server LAN address for all Student and Admin PCs.
