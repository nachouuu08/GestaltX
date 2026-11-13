#!/usr/bin/env python3
"""Validate the packaged IPA; macOS additionally verifies embedded signatures."""
import argparse
import hashlib
import json
import plistlib
from pathlib import Path
import subprocess
import tempfile
import zipfile

parser = argparse.ArgumentParser()
parser.add_argument("ipa", type=Path)
parser.add_argument("--verify-signatures", action="store_true")
args = parser.parse_args()
root = Path(__file__).resolve().parents[2]
components = []
with zipfile.ZipFile(args.ipa) as archive:
    if archive.testzip() is not None:
        raise SystemExit("Corrupt IPA entry")
    for name in archive.namelist():
        if name.startswith("/") or ".." in Path(name).parts:
            raise SystemExit("Unsafe archive path")
    app = "Payload/GestaltX.app"
    extension = app + "/PlugIns/GestaltXShare.appex"
    for bundle, source in [(app, "GestaltX/GestaltX.entitlements"),
                           (extension, "ShareExtension/GestaltXShare.entitlements")]:
        info = plistlib.loads(archive.read(bundle + "/Info.plist"))
        executable = info["CFBundleExecutable"]
        if "/" in executable or executable in (".", ".."):
            raise SystemExit("Invalid executable name")
        binary = archive.read(bundle + "/" + executable)
        # iOS device targets in this project are thin, little-endian arm64 Mach-O.
        if binary[:4] != bytes.fromhex("cffaedfe") or int.from_bytes(binary[4:8], "little") != 0x0100000C:
            raise SystemExit("Expected an arm64 device Mach-O executable")
        if info.get("CFBundleSupportedPlatforms") != ["iPhoneOS"]:
            raise SystemExit("Expected an iPhoneOS bundle")
        archive.read(bundle + "/_CodeSignature/CodeResources")
        components.append({"bundle": bundle, "identifier": info["CFBundleIdentifier"],
                           "executable_sha256": hashlib.sha256(binary).hexdigest(), "source": source})
        if bundle == extension and info.get("NSExtension", {}).get("NSExtensionPointIdentifier") != "com.apple.share-services":
            raise SystemExit("Share extension metadata missing")
    if not components[1]["identifier"].startswith(components[0]["identifier"] + "."):
        raise SystemExit("Extension bundle identifier does not belong to app")

if args.verify_signatures:
    with tempfile.TemporaryDirectory() as directory:
        subprocess.run(["ditto", "-x", "-k", str(args.ipa.resolve()), directory], check=True)
        groups = None
        for component in components:
            bundle = str(Path(directory) / component["bundle"])
            subprocess.run(["codesign", "--verify", "--deep", "--strict", bundle], check=True)
            signed = subprocess.run(["codesign", "-d", "--entitlements", "-", "--xml", bundle], check=True, capture_output=True)
            actual = plistlib.loads(signed.stdout)
            expected = plistlib.loads((root / component["source"]).read_bytes())
            if actual != expected:
                raise SystemExit("Packaged entitlements differ from source")
            current = set(actual.get("com.apple.security.application-groups", []))
            groups = current if groups is None else groups & current
        if not groups:
            raise SystemExit("No common App Group")
print(json.dumps({"ipa": args.ipa.name, "sha256": hashlib.sha256(args.ipa.read_bytes()).hexdigest(),
                  "signatures_verified": args.verify_signatures, "components": components}, indent=2))
