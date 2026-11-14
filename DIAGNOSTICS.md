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


## Reading baseline and public API limits
Schema 2 keeps the first successful reading independently of the last verified write. Boot identity is persisted locally using kern.boottime; zero or missing boot identity means unknown, not a confirmed restart. Comparisons list exact allowlisted keys with before/after values. A read-start has no values. Missing keys in a successfully read document remain absent. Existing archives without a reading baseline establish one on their next successful read.

The UI separates loaded MobileGestalt, pending preset selections, observed comparisons and write verification. Effective AI differences are exported with bounded values; other differences are counted without exporting their values. accept() continues resetting selections as in the original application.

Apple documents SystemLanguageModel.availability as availability of the on-device Foundation Models model for apps: https://developer.apple.com/documentation/foundationmodels/systemlanguagemodel/availability-swift.property
This is not a documented readiness check for the complete Siri pipeline. This edition therefore reports Siri functionality as unknown and does not query private services, instantiate generation sessions or invent download progress. Equal plist values establish observed stability only.


## Public availability query (schema 3)
The screen queries SystemLanguageModel.default.availability only, guarded by canImport(FoundationModels) and OS availability. It records the timestamp, available/deviceNotEligible/modelNotReady/appleIntelligenceNotEnabled, API unavailability or an unknown future response. The getter does not throw; error is reserved in the schema and is never fabricated. No LanguageModelSession, asset request or private-file inspection is used. Export includes the interpretation separately from Siri functionality and unknown download progress.

Public indicators investigated:
- https://developer.apple.com/documentation/foundationmodels/systemlanguagemodel — local model availability for app requests, not end-to-end Siri readiness.
- https://developer.apple.com/documentation/speech/sfspeechrecognizer — recognition service availability depends on locale and sometimes connectivity; not Siri model readiness.
- https://developer.apple.com/documentation/intents/inpreferences/siriauthorizationstatus() — authorization for this app to interact with Siri, not global functionality. These unrelated permissions are not requested or treated as readiness evidence.

Original baseline and verified-write comparisons use different-boot-from-baseline. Only comparison with the immediately preceding successful reading can report after-reboot. Successful reads persist that previous sample and boot identity; failed reads and write events do not advance it. On legacy archives without a previous boot sample, transition is unknown until a fresh successful read establishes it. Raw boot timestamps remain local. Stable flags, a storage size or an Updating label do not prove downloading or Siri functionality.
