#!/usr/bin/env python3
"""Verify the specific Flutter parsing regression is no longer present."""
from pathlib import Path

path = Path('lib/screens/digital_plus.dart')
assert path.is_file(), 'Missing digital_plus.dart'
source = path.read_text(encoding='utf-8')
assert 'class DigitalPlusScreen extends StatefulWidget' in source
assert source.count('          ]));\n      }),') == 1, 'Incorrect ListView/RefreshIndicator closure'
assert '          ])));\n      }),' not in source, 'Extra closing parenthesis remains'
assert 'class _DigitalDetailState extends State<_DigitalDetail>' in source
assert 'StorePlusService.updateDigital(' in source
assert 'SharePlus.instance.share(' in source
print('PASS: Build 28 DigitalPlus widget closings corrected; status/edit/share retained.')
