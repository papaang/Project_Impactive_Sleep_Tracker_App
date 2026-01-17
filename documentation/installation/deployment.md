# Deployment guide (for Developers)

This guide provides step-by-step instructions on how to manually build and publish the latest version of the application using the `.apk` file.

## 1. Update the code

For Android to accept the new APK as an "Update," the new version must usually be higher than the old one.

1.  Open your `pubspec.yaml` file in VS Code.
2.  Find the line with the current version eg `version: 1.0.0+1`.
3.  Change it to: `version: 1.0.1+2`.
4.  In the `settings_screen.dart` find the line with the current version eg `label: const Text("Version 2.0.3"),`.
5.  Change it to: `label: const Text("Version 2.0.4"),`.

## 2. How to to build an APK file.

1.  Open the Terminal in VS Code `Ctrl + ~`.
2.  Run this command: `flutter build apk --release`
3.  Once finished, navigate in your file explorer to: `[Your Project Folder]/build/app/outputs/flutter-apk/`.
4.  Find `app-release.apk`.
5.  Copy this file to your phone (via USB, Google Drive, or WhatsApp).
6.  Open the file on your phone and tap **Install**.

## 3. How to to create a Release on GitHub.

1. Go to the Repository main page and find the `Releases` section at the right-hand sidebar.
2. Click the text that says `Releases`.
3. Click the button that says `Draft a new release` (usually near the top right).
4. Click the dropdown and create a new tag eg `v1.0.0`
5. Give the release a title eg `Version 1.0.0`.
6. Scroll down to the box that says **"_Attach binaries by dropping them here or selecting them_"**.
7. Drag and drop your `app-release.apk` file from your computer into this box.

> **_Reminder_:** Your file is located in your project folder at: `build/app/outputs/flutter-apk/app-release.apk`.
8. Wait for the green progress bar to finish uploading the file. Click the green _**Publish release**_ button at the bottom to publish the release.

