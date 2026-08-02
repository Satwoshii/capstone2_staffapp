# Syswatch Admin App

## Version

```text
v2.4.1
```

## Overview

The **Syswatch Admin App** is the central management application for the Syswatch intranet system.

It now uses:

- Flutter Windows
- PHP local API
- MariaDB central database
- Apache/XAMPP
- Laboratory LAN or private network

Firebase and Firestore are no longer used by the active Admin App.

Public internet is not required.

---

## Admin Role

The former ITSO and Admin roles were combined into one role:

```text
Admin
```

The Admin role handles:

- Accounts
- Rooms
- Workstations
- PC health
- Reports
- Repairs
- Maintenance records
- Last known user
- ITSO Support Chat

The chat interface may still be labeled **ITSO Support**, but it is managed through an Admin account.

---

## Admin Authentication

Admin login now uses:

- PHP/MariaDB authentication
- API access tokens
- Local token storage
- Session expiration handling
- Sign-out and token clearing
- Configurable server URL

Firebase Authentication is no longer used.

---

## Account Management

The Admin App can:

- Create Student accounts
- Create Admin accounts
- View accounts
- Search accounts
- Filter accounts
- Enable users
- Disable users
- Reset passwords
- Prevent duplicate emails
- Prevent duplicate Student IDs

Student self-registration is not allowed.

---

## Room Management

The Admin can:

- Create rooms
- Edit room details
- Set room capacity
- Enable rooms
- Disable rooms
- View workstations assigned to a room

Example:

```text
Room: 706
Capacity: 40
Status: Active
```

---

## PC Health Monitoring

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

---

## Reports

The Admin can review:

- Student issue reports
- Peripheral reports
- Hardware fault reports
- PC health reports
- Severity
- Status
- Room and PC details
- Student details
- Date and time

---

## Repair and Maintenance Management

The Admin can:

- View unresolved faults
- Open fault details
- Add repair notes
- Update repair status
- Mark issues as resolved
- Reopen issues when necessary
- Record maintenance history
- Track resolved and unresolved problems

When an issue is resolved, the linked chat becomes read-only.

---

## Last Known User

The Admin can view:

- Student name
- Student ID
- Room
- PC ID
- Login time
- Latest session details

This helps identify the last student who used a workstation before a fault was detected or reported.

---

## Issue-Gated ITSO Support Chat

The Admin App now includes:

```text
ITSO Support
```

Only conversations linked to active or previously resolved workstation issues appear in this section.

Students cannot start general or unrelated conversations.

### Admin chat features

The Admin can:

- View active support requests
- View resolved conversations
- Search conversations
- Filter by active, resolved, or all
- View Student name and ID
- View room and PC
- View issue type and severity
- Reply to the student
- View unread messages
- Change the issue status
- Assign an Admin
- Add maintenance notes
- Mark the issue as repaired
- Resolve or reopen a conversation

### Supported issue statuses

```text
open
acknowledged
in_progress
waiting_for_student
waiting_for_repair
resolved
closed
```

### Student message access

| Issue status | Student can send messages |
|---|---:|
| Open | Yes |
| Acknowledged | Yes |
| In progress | Yes |
| Waiting for student | Yes |
| Waiting for repair | Yes |
| Resolved | No |
| Closed | No |

### One conversation per issue and student

Each support conversation is linked to one fault report and one student.

Example:

```text
Fault Report: RAM issue
Room: 706
PC: PC-03
Student: 2026-00001
Conversation: ITSO Support Request
```

A different issue creates another conversation.

---

## Chat Database Tables

The corrected v2.4.1 chat schema uses:

```text
chat_conversations
chat_messages
```

### `chat_conversations`

Required fields:

```text
id
fault_report_id
student_user_id
workstation_id
assigned_admin_id
status
created_at
updated_at
resolved_at
```

### `chat_messages`

Required fields:

```text
id
conversation_id
sender_user_id
sender_role
client_message_id
message
read_by_student
read_by_admin
created_at
```

The old fields below are no longer used by the v2.4.1 PHP endpoints:

```text
delivery_status
read_at
```

---

## PHP Chat Endpoints

The server must contain:

```text
chat/chat_helpers.php
chat/admin_conversations.php
chat/admin_messages.php
chat/admin_send.php
chat/admin_update_status.php
chat/admin_mark_read.php

chat/student_active_issues.php
chat/student_open.php
chat/student_messages.php
chat/student_send.php
chat/student_mark_read.php
```

The final location should be:

```text
C:\xampp\htdocs\syswatch_api\chat
```

---

## Chat Requirements

For chat to work:

1. The Student App must be v2.4.1.
2. The Admin App must contain the ITSO Support screen.
3. The PHP chat endpoints must be installed.
4. The corrected chat schema must be imported.
5. Apache and MariaDB must be running.
6. The fault report must exist in MariaDB.
7. The issue must be active and unresolved.
8. The Student must have an active session.

---

## Common Chat Errors

### `Could not load support requests`

Possible causes:

- Missing PHP chat files
- Incorrect table columns
- PHP SQL error
- Missing API token
- Database schema mismatch

Check:

```text
C:\xampp\apache\logs\error.log
```

### Student shows `ITSO Support unavailable`

Possible causes:

- The issue is only local and has not synchronized
- No active fault exists in MariaDB
- PHP chat endpoint is unavailable
- Workstation token is invalid
- Student session is missing
- Server is offline

### Empty conversation list

An empty list is normal when no student has opened a conversation for an active issue.

---

## Server Address

Same-PC server:

```text
http://127.0.0.1/syswatch_api
```

Another computer on the LAN:

```text
http://192.168.1.10/syswatch_api
```

VirtualBox host-only development address:

```text
http://192.168.56.1/syswatch_api
```

---

## Windows Installer

The Admin installer:

- Packages the complete Flutter Windows Release folder
- Includes Flutter data, plugins, and DLL files
- Includes the Microsoft Visual C++ x64 runtime
- Creates Start Menu and desktop shortcuts
- Prevents missing runtime DLL errors

Expected installer:

```text
Syswatch_Admin_Setup_v2.4.1.exe
```

The Windows installer does not install the PHP API or MariaDB schema.

---

## Testing Completed

- Admin App uses the local PHP API
- Admin-only role is active
- Account screens use MariaDB
- Room screens use MariaDB
- PC Health uses MariaDB
- Reports and Repairs use MariaDB
- Last Known User uses MariaDB
- ITSO Support menu is present
- Chat tables were created
- The v2.4.1 Student App displays the support button
- Windows installer includes the Visual C++ runtime

---

## Remaining Tests

- Full Admin login after clean installation
- Create Student account
- Create Admin account
- Enable and disable accounts
- Reset password
- Create and update rooms
- Live workstation heartbeat
- Full Student-to-Admin chat exchange
- Message read/unread updates
- Issue status changes
- Repair completion and chat resolution
- Reopen resolved issue
- Multiple simultaneous support conversations
- Clean VM installer testing

---

## Important Notes

- Firebase data is not migrated automatically.
- The Admin App must use the LAN IP when XAMPP is on another computer.
- Only trusted personnel should receive Admin accounts.
- The corrected PHP chat folder and MariaDB schema must remain installed on the server.
