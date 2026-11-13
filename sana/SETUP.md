# CampusFlow setup and verification

## iOS

Open `../sana.xcodeproj` on a Mac. The project uses a synchronized source folder, so the new Swift files are included automatically. Existing FirebaseFunctions package linkage is used; no Gemini SDK or client API key is needed. Build and run on an iOS simulator/device using Xcode.

## Firebase and Gemini

The deployment configuration lives in `sana/Backend`, independently of the older rules file in the repository root. Deploy **these** rules: they protect the server-only quota collection. Firestore creates collections on the first write; there are no SQL tables or manual indexes to create.

Run from `sana/Backend` using an authenticated Firebase CLI:

```sh
firebase use --add
cd functions
npm install
cd ..
firebase functions:secrets:set GEMINI_API_KEY
firebase deploy --only functions:generateRevisionPlan,firestore:rules
```

Choose the same Firebase project as `GoogleService-Info.plist`. Cloud Functions deployment requires a billing-enabled project and access to the Gemini API. The callable function uses the default `us-central1` region, matching the Swift client. The API key is stored in Secret Manager, never in the iOS bundle or Firestore. To change the Gemini model, update the endpoint in `Backend/functions/index.js` and redeploy. Provider API reference: https://ai.google.dev/api/generate-content

Data paths:

- `users/{uid}/tasks/{id}`: existing tasks.
- `users/{uid}/courses/{id}`: existing courses.
- `users/{uid}/events/{id}`: title, course, notes, start/end timestamps, and kind (`study`, `exam`, `revision`).
- `users/{uid}/private/revisionQuota`: server-only daily and request-frequency limits.

Calendar includes task deadlines and events crossing midnight. Events support creation, editing, and confirmed deletion. Revision plans are generated only after the user presses Generate, with a disclosure explaining what is sent. Plans are reviewed before an atomic calendar save. Sessions begin at 09:00 (or the current time for today), include ten-minute gaps, and move past already loaded events. They can be edited in Calendar afterward. There is no cross-device scheduling lock; simultaneous calendar edits can still overlap.

## Checks

```sh
node --check Backend/functions/index.js
node --test Backend/functions/validation.test.js
```

These cover request limits, daily budgets, invalid generated data, ordering and unique session IDs. Live Firebase/Gemini and Firestore emulator tests require deployed services/dependencies and credentials and have not been run here. No Xcode or Swift compiler is available in the Windows workspace, so an iOS build and visual review remain required.

Device acceptance checks:

1. Sign in with email and Google; verify locker unlock and Continue. Sign out and sign back in.
2. From Profile → Settings switch Arabic → French → English → Arabic. Confirm tab direction, navigation buttons, labels, dates, and persisted selection after relaunch.
3. Add/edit/delete an event; inspect it after relaunch and on another device using the same account. Confirm another account cannot read it.
4. Generate French, English and Arabic plans; test no key, offline, quota limit, then save a plan and check calendar sessions. Double tapping Save must not duplicate sessions.
5. Review light/dark mode, large text, VoiceOver and Reduce Motion on all screens.

Calendar events currently do not schedule push/local reminders; the existing task deadline reminder feature remains available in Settings.
