# Syswatch Admin App

## Overview

The **Syswatch Admin App** is the management application for the Syswatch intranet system.

It has been converted from Firebase into a local PHP/MariaDB application.

The former ITSO and Admin roles are now merged into one role:

```text
Admin
```

Public internet is not required.

---

## Main Purpose

The Admin App allows authorized personnel to:

- Manage accounts
- Manage rooms
- View workstations
- Monitor PC health
- Review reports
- Manage repairs
- View maintenance history
- View the last known student
- Configure the local server connection

---

## Added and Updated Features

### 1. Local Admin authentication

Admin login now uses:

- PHP local API
- MariaDB user accounts
- API access tokens
- Local token storage
- Session expiration handling
- Sign-out and token clearing

Firebase Authentication is no longer used.

### 2. One Admin role

The separate ITSO role was removed.

All management functions now belong to the `admin` role.

Admin can:

- Create Student accounts
- Create additional Admin accounts
- Manage rooms
- View PC health
- Review reports
- Manage repairs
- View last-known-user data

### 3. Account management

The Admin App can:

- Create Student accounts
- Create Admin accounts
- View accounts
- Search accounts
- Filter accounts
- Enable accounts
- Disable accounts
- Reset passwords
- Prevent duplicate email addresses
- Prevent duplicate Student IDs

Student self-registration is intentionally disabled.

### 4. Room management

The Admin can:

- Add rooms
- Edit room information
- Set room capacity
- Enable rooms
- Disable rooms
- View workstations assigned to rooms

Example:

```text
Room: 706
Capacity: 40
Status: Active
```

### 5. PC health monitoring

The Admin can view:

- Room
- PC ID
- Workstation ID
- Online or offline status
- Latest heartbeat
- Keyboard status
- Mouse status
- Monitor status
- Ethernet status
- CPU status
- RAM status
- Disk status
- Storage-health status
- Severity
- Latest report time

### 6. Reports

The Admin can review:

- Student issue reports
- Peripheral reports
- Fault reports
- PC health reports
- Severity
- Status
- Room and PC details
- Date and time

### 7. Repair management

The Admin can:

- View unresolved faults
- Open fault details
- Add repair notes
- Update repair status
- Mark issues as resolved
- Record maintenance history
- Track resolved and unresolved problems

### 8. Last known user

The Admin can view:

- Student name
- Student ID
- Room
- PC ID
- Login time
- Latest session information

This helps identify who last used the workstation before a problem was reported.

### 9. Configurable server address

Use this when the Admin App and XAMPP are on the same computer:

```text
http://127.0.0.1/syswatch_api
```

Use the server PC's LAN IP from another computer:

```text
http://192.168.1.10/syswatch_api
```

For the VirtualBox host-only test:

```text
http://192.168.56.1/syswatch_api
```

### 10. API token handling

The Admin App now sends a local access token to protected PHP endpoints.

The server accepts:

```text
Authorization: Bearer <token>
```

and the Syswatch fallback token header when needed by XAMPP/Apache.

This fixed the previous error:

```text
A user access token is required.
```

### 11. Async screen fixes

The Admin App screens were corrected so asynchronous work is not performed inside `setState()`.

This fixed errors on:

- PC Health
- Repairs
- Last Known User
- Rooms
- Accounts

### 12. Removed Firebase files

The active Admin App no longer uses:

- `firebase_core`
- `firebase_auth`
- `cloud_firestore`
- `firebase_options.dart`
- `firebase_user_service.dart`
- Firestore model types
- Firebase timestamps

---

## How the Admin App Works Now

### Admin login

1. Start the PHP and MariaDB server.
2. Open the Admin App.
3. Check the server address.
4. Enter the Admin email and password.
5. The PHP API verifies the account.
6. The server returns an access token.
7. The app saves the token locally.
8. The dashboard opens.

### Create a Student account

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
6. The account is stored in MariaDB.
7. Student PCs can download the account for offline login.

### Create an Admin account

1. Open **Accounts**.
2. Select **Add Account**.
3. Choose `Admin`.
4. Enter the required details.
5. Save the account.

### Manage rooms

1. Open **Rooms**.
2. Add or edit a room.
3. Set the room capacity.
4. Set the active status.
5. Save the room.

### Review PC health

1. Open **PC Health**.
2. Select a room or workstation.
3. Review the current status.
4. Open detailed information when needed.

### Repair workflow

1. Open **Repairs**.
2. Select a fault report.
3. Review the issue.
4. Add a maintenance note.
5. Update the status.
6. Mark the issue as resolved after verification.

### Last known user

1. Open **Last Known User**.
2. Search by room or PC.
3. Review the latest student and session details.

---

## PHP/MariaDB Server Features Used by the Admin App

The Admin App uses local endpoints for:

- Admin login
- Logout
- Account list
- Account creation
- Account activation
- Password reset
- Room list
- Room creation
- Room activation
- Dashboard data
- PC health
- Fault reports
- Repair management
- Last known users

The MariaDB database contains tables such as:

```text
users
api_tokens
auth_sessions
rooms
workstations
pc_status
fault_reports
maintenance_logs
login_logs
audit_logs
```

---

## Windows Installer

The Admin installer:

- Packages the complete Flutter Windows release folder
- Installs the app under Program Files
- Creates Start Menu and optional desktop shortcuts
- Includes the Microsoft Visual C++ x64 runtime
- Prevents missing runtime DLL errors
- Launches Syswatch Admin after installation

Expected installer name:

```text
Syswatch_Admin_Setup_v2.3.3.exe
```

---

## Testing Completed

- Admin App converted from Firebase to local API
- Admin-only role applied
- Account screens converted
- Room screens converted
- PC Health screens converted
- Report screens converted
- Repair screens converted
- Last-known-user screens converted
- Access-token handling fixed
- Async `setState()` errors fixed
- Invalid icon references fixed
- Firebase dependencies removed
- MariaDB tables imported successfully
- Server health endpoint confirmed online

---

## Remaining Tests

- Full Admin login after installation
- Create Student account
- Create Admin account
- Disable and enable accounts
- Reset passwords
- Create and update rooms
- View live Student PC heartbeat
- Review reports from multiple PCs
- Complete repair workflow
- Verify last-known-user records
- Test the Admin installer on a clean PC or VM

---

## Important Notes

- Existing Firebase data is not migrated automatically.
- Old accounts, rooms, reports, and logs must be migrated separately.
- The Admin App must use the server LAN IP when XAMPP is on another computer.
- Only trusted personnel should receive Admin accounts.
