# unifi setup

## Build and delivery

Use Apple's Xcode tools (`xcodebuild`) for native iOS builds and tests, and Xcode Cloud for automated builds and TestFlight delivery. Codemagic is not required.

Xcode Cloud requires initial workflow configuration in Xcode on a Mac. After that, GitHub changes can trigger cloud builds while development requests and reviews are controlled from iPhone.

## Current status

Repository branch creation and file writes were verified through the connected integration. This setup document does not activate cloud builds, provision coding agents, configure Firebase, or distribute an app.

The prepared app foundation still requires upload, replacement of its earlier Codemagic configuration with the Apple-based workflow, and macOS compilation and testing before use.

Keep Google configuration and Apple signing credentials out of the repository. Supply them through the corresponding service's protected settings.
