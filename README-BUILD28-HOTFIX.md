# AGAN PONSEL Build 28 — Dart Syntax Hotfix 1

Target: v1.8.0+28. GitHub Actions run #35 failed at `dart format lib test` with
`lib/screens/digital_plus.dart:86:13 Expected to find ';'`.

Cause: `return RefreshIndicator(child: ListView(children: [...]))` has one extra
closing parenthesis at the end of its `children` list.

Fix: change `          ])));` to `          ]));` immediately before `      }),`.
No database, payment, stock, build version, or existing feature is changed.

## Termux

```sh
cd ~/agan-build/agan_ponsel_flutter
grep '^version:' pubspec.yaml
unzip -o /sdcard/Download/AGAN-PONSEL-Build28-Dart-Syntax-Hotfix1.zip
python3 scripts/apply_build28_syntax_hotfix.py
python3 scripts/check_build28_syntax_hotfix.py
git diff --check
git add lib/screens/digital_plus.dart scripts/apply_build28_syntax_hotfix.py scripts/check_build28_syntax_hotfix.py README-BUILD28-HOTFIX.md
git commit -m "Fix Build28 DigitalPlus closing parentheses"
git push origin main
```

Do not uninstall or clear app data. GitHub Actions must still compile/analyze
and run unit tests before the APK can be considered verified.
