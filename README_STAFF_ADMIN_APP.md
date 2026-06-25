# ITSO/Admin Management App

This is the normal staff app. It does not use startup, kiosk mode, tray mode, or student authentication.

Features:
- Staff login using Firebase Auth
- Role-based access from Firestore users/{uid}
- ITSO can view PC health, mark repairs, view last known user, and reports
- Admin can also manage rooms and accounts

Same Firebase project is used as the Student PC App. Do not create a new Firebase project.

Important:
- PC Configuration stays in the Student PC App hidden shortcut because it configures the local laboratory computer.
- Press Ctrl + Shift + A in the Student PC App, login as admin, then configure that local PC.
