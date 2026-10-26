# AGAN PONSEL v2.1.0 Build31 — Dependency Hotfix

**GitHub Actions run #40:** `Generate Android platform (if needed)` fails while resolving packages.

The combination of `package_info_plus: ^8.3.1` and `flutter_secure_storage: ^11.2.0` requires incompatible `win32` major versions. Flutter's solver proposes `package_info_plus: ^10.2.2`.

This hotfix:

- Updates **only** `package_info_plus` in `pubspec.yaml` to `^10.2.2`.
- Updates the Build31 source guard `scripts/check_build31.py` to require the new package version.
- Preserves `flutter_secure_storage: ^11.2.0` and the `shared_preferences_android: 2.4.28` Android release hotfix.
- Does not edit SQLite, backups, app features, PIN, or customer transactions.

## Termux

```sh
cd ~/agan-build/agan_ponsel_flutter
unzip -o /sdcard/Download/AGAN-PONSEL-Build31-Dependency-Hotfix1.zip
python3 scripts/apply_build31_dependency_hotfix.py
python3 scripts/check_build31_dependency_hotfix.py
python3 scripts/check_build31.py
python3 scripts/selftest_build31_dependency_hotfix.py
git diff --check
git add pubspec.yaml scripts/check_build31.py scripts/apply_build31_dependency_hotfix.py scripts/check_build31_dependency_hotfix.py scripts/selftest_build31_dependency_hotfix.py README-BUILD31-DEPENDENCY-HOTFIX.md
git commit -m "Fix Build31 package_info_plus win32 dependency conflict"
git push origin main
```

Check GitHub Actions: https://github.com/adelibra23/agan-ponsel-flutter/actions

`package_info_plus ^10.2.2` requires recent Flutter stable (Flutter >=3.38.1, Dart >=3.10.0) and Android Gradle Plugin >=8.12.1; the project uses Flutter stable in CI. Resolve/build outcomes must be verified by a new GitHub Actions run.

**Do not uninstall your existing APK or clear app data.** Back up shop data before installing any future APK update.
