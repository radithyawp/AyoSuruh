# Ayo Suruh iOS Phase 4 — iOS 15 Deployment Target

The Codemagic unsigned build reached CocoaPods successfully but Firebase Core 12.17.0 requires iOS 15 or later.

This patch:
- sets the Runner deployment target to iOS 15.0 for Debug, Profile, and Release;
- adds an explicit iOS Podfile with `platform :ios, '15.0'`;
- forces installed Pods to use iOS 15.0 as the minimum deployment target.

No Android source, Supabase logic, Firebase options, authentication code, or application business logic is changed.

After applying, commit and push to both `origin` and the `codemagic` mirror, then rerun the `Ayo Suruh iOS - Unsigned CI` workflow.
