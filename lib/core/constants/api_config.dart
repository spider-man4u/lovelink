class ApiConfig {
  ApiConfig._();

  // Pass via --dart-define=GEMINI_API_KEY=your_key_here
  // Or set this directly (not recommended for production)
  static const String geminiApiKey = String.fromEnvironment(
    'GEMINI_API_KEY',
    defaultValue: 'AIzaSyAL0WSCA-eYus8yFPy8T2FByTQG8jnDXJw',
  );

  // Unsplash API credentials
  // Pass via --dart-define=UNSPLASH_ACCESS_KEY=your_key_here
  static const String unsplashAccessKey = String.fromEnvironment(
    'UNSPLASH_ACCESS_KEY',
    defaultValue: 'HiUWKVy1miiCu95gcST0H0O4wptuN6xbne25BW6gWUQ',
  );
}
