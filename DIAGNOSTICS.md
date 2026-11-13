# Experimental persistence diagnostics

The existing SwiftUI manager stages edits; the GestaltFileStore actor acquires the existing sandbox extension, backs up the cache, validates freshness, writes, compares full typed plist readback, and restores previous bytes on failure. The existing text log remains unchanged. Diagnostic hooks observe this path without changing capabilities, identity checks, exploit or activation values.

Open Diagnóstico avanzado to read and compare, view events, or export JSON. A verified device write saves an allowlisted typed flag baseline. A later successful device read compares against that baseline, retaining it even after mismatches. Darwin kern.boottime distinguishes same-boot reads from post-reboot reads. No write baseline means no persistence conclusion. Restart manually, reopen the app and read again. A match does not establish Apple Intelligence availability or resource download success. Local plist edits do not establish a device baseline.

Only eight known AI/Siri flag keys and bounded numeric/boolean values are captured. Other types are redacted. Export contains OS/model class, access method, random diagnostic session/event IDs and timestamps, never raw error text, installation IDs, paths, boot timestamps, credentials, full plist data or the existing unrestricted text logs. Events are bounded to 500. Storage failure is reported in the export. Recording is automatic for device reads/writes in this experimental edition.

## Validation

On macOS: swiftc GestaltX/AdvancedDiagnostics.swift tests/AdvancedDiagnosticsTests.swift -o /tmp/gx-diagnostics && /tmp/gx-diagnostics

The dedicated manual/PR workflow runs these isolated tests. The app target synchronizes the GestaltX source directory, so new Swift files require no project-file edits. Windows cannot validate SwiftUI, Darwin APIs, native iOS libraries or device behavior. Physical iPhone 12 / iOS 27 beta validation remains necessary.

## IPA CI investigation

The existing Build IPA workflow has workflow_dispatch with a ref input; choose diagnostic-ai after pushing to a fork. Its script disables Xcode signing, then uses codesign -s - for ad hoc signatures and packages Payload as IPA, preserving App Group entitlements. No private signing certificate is used. Installing requires a compatible re-signing tool and usable App Groups. A generated IPA alone does not guarantee device access.

The diagnostic branch uses GitHub-hosted macos-latest runners and runs isolated Swift tests and localization checks before building. Branch pushes also trigger the existing IPA workflow. The packaged IPA is checked for arm64 executables, extension metadata, signatures and exact source entitlements before upload. The existing workflow publishes release assets only when TAG is set; a manual branch run has no TAG. No release or device action was performed.
