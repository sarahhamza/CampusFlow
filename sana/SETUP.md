# CampusFlow setup

Open `../sana.xcodeproj` on a Mac and build using Xcode. Source files in the synchronized app folder are included automatically.

## Firebase calendar

The app uses Firebase Authentication and Cloud Firestore directly. Calendar events are stored under `users/{uid}/events/{id}` with title, course, notes, start/end timestamps, and kind (`study` or `exam`). Firestore creates the collection on the first write. Task deadlines appear in Calendar alongside events.

Use the same Firebase project as `GoogleService-Info.plist`. Its deployed Firestore rules must allow authenticated users to read and write their own `events` subcollection. The existing repository-root `firestore.rules` allows user-owned subcollections. Publish it through Firebase Console if needed.

## Device verification

- Sign in and verify the locker screen, then continue to the dashboard.
- Switch Arabic, French and English in Profile settings and verify labels and layout direction.
- Add, edit and delete calendar events; verify persistence after relaunch.
- Review light/dark mode, large text and Reduce Motion.

An iOS build and visual verification require Xcode on a Mac and have not been run in this Windows workspace. Calendar events do not schedule reminders; task deadline reminders remain available in Settings.
