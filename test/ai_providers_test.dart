import 'package:flutter_test/flutter_test.dart';
import 'package:agan_ponsel/services/ai_gateway.dart';

void main() {
  test('Tiga provider dikenal dan default memilih router gratis', () {
    expect(AiProviders.all.length, 3);
    expect(AiProviders.byId('openrouter').model, 'openrouter/free');
    expect(AiProviders.byId('groq').model, 'openai/gpt-oss-20b');
    expect(AiProviders.byId('provider_tidak_ada').id, 'openrouter');
  });
  test('URL pengambilan key selalu HTTPS', () {
    for (final provider in AiProviders.all) {
      expect(Uri.parse(provider.keyUrl).scheme, 'https');
    }
  });
}
