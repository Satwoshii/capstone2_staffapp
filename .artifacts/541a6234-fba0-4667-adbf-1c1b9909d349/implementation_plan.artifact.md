# Implementation Plan - Replace Silver/Black Gradients with Single Color

The user wants to simplify the UI by replacing buttons that use a silver gray and black gradient with a single solid color. This affects several screens where this "accent gradient" is used for primary actions, badges, and icons.

## Proposed Changes

We will replace the `_accentGradient` (and similar hardcoded gradients) with a single color that adapts to the theme:
- **Dark Mode**: Silver Gray (`0xFFC0C0C0`)
- **Light Mode**: Black (`0xFF000000`)

This matches the pattern established in the `StaffLoginScreen` for the main action button.

### [Component Name]

#### [MODIFY] [teacher_chat_screen.dart](file:///C:/Users/carlo/OneDrive/Desktop/StaffApp/capstone2_staffapp/lib/screens/teacher_chat_screen.dart)
- Replace `_accentGradient` getter with `_accentColor`.
- Update `_topBar` icon badge to use solid color.
- Update `_messageBubble` to use `color` instead of `gradient`.
- Update `_sendButton` to use solid color.
- Update `_emptyState` icon badge to use solid color.
- Update `_errorState` retry button to use solid color.
- Update `_message` (SnackBar) icon badge to use solid color.

#### [MODIFY] [support_chat_screen.dart](file:///C:/Users/carlo/OneDrive/Desktop/StaffApp/capstone2_staffapp/lib/screens/support_chat_screen.dart)
- Replace `_accentGradient` getter with `_accentColor`.
- Update `_buildStatusFilter` to use solid color for the selected option.
- Update `_buildConversationList` unread badge to use solid color.
- Update `_CategoryBadge` to use solid color.
- Update `_GradientButton` and `_SendButton` to use solid color (renaming if necessary, or just keeping the widget names).
- Update `_AdminMessageBubble` to use solid color.

#### [MODIFY] [teacher_dashboard_screen.dart](file:///C:/Users/carlo/OneDrive/Desktop/StaffApp/capstone2_staffapp/lib/screens/teacher_dashboard_screen.dart)
- Replace `_accentGradient` getter with `_accentColor`.
- Update `_topBar` logo badge to use solid color.
- Update `_gradientButton` to use solid color.
- Update `_sectionCard` icon badge to use solid color.
- Update `_pcTile` to use solid color instead of gradient if applicable (it uses a subtle color-to-field gradient).
- Update `_dialogTitle` and `_dialogPrimaryButton`.

#### [MODIFY] [staff_login_screen.dart](file:///C:/Users/carlo/OneDrive/Desktop/StaffApp/capstone2_staffapp/lib/screens/staff_login_screen.dart)
- Update `_buildLogoBadge` to use a solid color instead of the subtle gradient.

#### [MODIFY] [account_management_screen.dart](file:///C:/Users/carlo/OneDrive/Desktop/StaffApp/capstone2_staffapp/lib/screens/account_management_screen.dart)
- Update `_buildUserTile` avatar to use a solid color background and icon.

## Verification Plan

### Manual Verification
- Launch the app and navigate through the modified screens (`TeacherDashboard`, `TeacherChat`, `SupportChat`, `AccountManagement`).
- Verify that all buttons previously having a gradient now show a solid color (Black in light mode, Silver in dark mode).
- Ensure text and icon legibility remains high (e.g., black text on silver, white text on black).
