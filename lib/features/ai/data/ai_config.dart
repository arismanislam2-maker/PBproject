/// OpenRouter API key is supplied at build time through --dart-define.
/// Example: flutter run --dart-define=OPENROUTER_API_KEY=your_key
const String openRouterApiKey = String.fromEnvironment(
  'OPENROUTER_API_KEY',
  defaultValue: '',
);

