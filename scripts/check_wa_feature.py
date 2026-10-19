"""Simple source-structure guard, not a substitute for Flutter compiler/tests."""
from pathlib import Path
r=Path(__file__).resolve().parents[1]
settings=(r/'lib/screens/settings/ai_settings.dart').read_text()
gateway=(r/'lib/services/ai_gateway.dart').read_text()
menu=(r/'lib/screens/others.dart').read_text()
wa=(r/'lib/screens/settings/whatsapp_agent_settings.dart').read_text()
assert 'readStoredKey' in gateway
assert "keyController.text = savedKey ?? ''" in settings
assert 'obscureText: hideKey' in settings
assert 'WhatsappAgentSettingsScreen' in menu
assert 'WhatsappAgentApi.status()' in wa
assert 'WhatsappAgentApi.setEnabled' in wa
assert 'shared_preferences_android: 2.4.28' in (r/'pubspec.yaml').read_text()
assert 'node --test' in (r/'.github/workflows/build-apk.yml').read_text()
print('AGANA WA source guard passed')
