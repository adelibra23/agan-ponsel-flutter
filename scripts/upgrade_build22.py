"""Integrate AGAN PONSEL Build22 overlay on top of Build21 safely.
Run AFTER unpacking the Build22 patch in the repository root.
Other Dart files outside the receivables module are not touched.
"""
from pathlib import Path
import re

root=Path(__file__).resolve().parent.parent
pub=root/'pubspec.yaml'
workflow=root/'.github/workflows/build-apk.yml'
readme=root/'README.md'
changelog=root/'CHANGELOG.md'

assert pub.exists() and workflow.exists(), 'Jalankan dari folder proyek AGAN PONSEL'
spec=pub.read_text()
wf=workflow.read_text()
assert 'shared_preferences_android: 2.4.28' in spec, 'Hotfix startup Build20 hilang! Jangan lanjut.'
assert (root/'lib/screens/settings/whatsapp_agent_settings.dart').exists(), 'Source Build21 WhatsApp belum ditemukan. Gunakan Build21 lebih dulu.'
assert "version: 1.1.0+21" in spec or "version: 1.2.0+22" in spec, 'Versi proyek bukan Build21/22. Jangan menimpa versi lain.'
assert 'AGAN-PONSEL-v1.1.0-Build21-APK' in wf or 'AGAN-PONSEL-v1.2.0-Build22-APK' in wf
assert 'scripts/smoke_receivable_details.py' in wf
assert 'scripts/smoke_receipt_v10.py' in wf
assert "'databaseVersion': 11" in (root/'lib/services/backup_service.dart').read_text()
assert 'version: 11' in (root/'lib/core/database.dart').read_text()

spec=spec.replace('version: 1.1.0+21', 'version: 1.2.0+22', 1)
wf=wf.replace('AGAN-PONSEL-v1.1.0-Build21-APK','AGAN-PONSEL-v1.2.0-Build22-APK',1)
marker='''      - name: Analyze Flutter code
'''
step='''      - name: Smoke test v11 payment edits and dated bon
        run: python3 scripts/smoke_receivable_v11.py

'''
if step not in wf:
    assert marker in wf
    wf=wf.replace(marker,step+marker,1)
command='test/receivable_receipt_test.dart'
addition='test/receivable_build22_test.dart'
if addition not in wf:
    assert command in wf
    wf=wf.replace(command,command+' '+addition,1)
assert 'WhatsApp Agent Webhook' in wf, 'Workflow Build21 WhatsApp belum ada, perlu cek versi.'
pub.write_text(spec);workflow.write_text(wf)

note='''\n\n## AGAN PONSEL v1.2.0 Build22\n- Koreksi pembayaran dengan alasan dan jejak audit sebelum/sesudah.\n- Tanggal per barang/bon dan tombol Tambah Bon ke piutang pelanggan yang sama.\n- Penyesuaian tanggal jatuh tempo, salin ringkasan piutang, aktivitas bon tambahan.\n- Migrasi SQLite v11 dan kompatibilitas backup v4..v11.\n- Build21 WhatsApp dan plugin preferences override tetap dipertahankan.\n'''
for path in (readme,changelog):
    if path.exists() and '## AGAN PONSEL v1.2.0 Build22' not in path.read_text():
        path.write_text(path.read_text()+note)
print('OK: Build22 version, workflow + tests integrated; AGANA WhatsApp / startup fixes preserved')
