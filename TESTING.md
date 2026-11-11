# LAND METRICS: real-device testing plan

I cannot run your app on phones, so this is the plan to run it yourself before every release.

## Devices (minimum)
- Android: one low-end phone (2 GB RAM, Android 10 or 11), one mid-range (Android 13), one recent (Android 14 or 15). Include a Tecno or Infinix and a Samsung, which are common in Nigeria.
- iPhone (when you ship iOS): one older (iPhone 11 or SE) and one recent.
- Test on Wi-Fi, on mobile data, and on a slow connection.

## Cloud real devices (no phones needed)
Firebase Console > Test Lab > Run a test > Robo test > upload `app-release.apk` > pick 3 to 5 physical devices. It taps through the app and reports crashes and screenshots.

## Manual checklist (tick each on every device)
1. Install a fresh APK. Splash shows, logo and icon are correct.
2. Register with a new email (the Terms box must be ticked). Log out, log in. Close and reopen: still signed in.
3. Forgot password: code arrives by email and the new password works.
4. Sell a land listing and a property listing with 3 photos. Try "Write with AI".
5. Log in as admin: confirm the listing. As the seller: bell shows a notification, pay the subscription, admin verifies, listing goes live.
6. As a second user: buy the listing, attach a receipt. As admin: verify. Seller dashboard shows net gains (price minus 10%).
7. Construction application with all required documents. Admin opens each document.
8. Ask AI a question. Chat with admin from both sides.
9. Turn on airplane mode on each screen: red banner and "No internet connection" appear, no technical text anywhere. Turn it off and tap Try again.
10. Change profile picture. Change password. Delete a test account: login no longer works.
11. Push (after Firebase is set up): close the app fully, have the admin send a broadcast: the phone shows it.
12. Dark mode, large font size, rotate the phone, back button behaviour.

## Release gate
Do not publish unless steps 1 to 10 pass on all devices, `flutter test` is green in GitHub Actions, and Sentry shows no new crashes during testing.
