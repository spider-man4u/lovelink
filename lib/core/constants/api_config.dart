class ApiConfig {
  ApiConfig._();

  // Pass via: --dart-define=GEMINI_API_KEY=your_key_here
  static const String geminiApiKey = String.fromEnvironment(
    'GEMINI_API_KEY',
    defaultValue: 'AIzaSyAL0WSCA-eYus8yFPy8T2FByTQG8jnDXJw',
  );

  // Pass via: --dart-define=UNSPLASH_ACCESS_KEY=your_key_here
  static const String unsplashAccessKey = String.fromEnvironment(
    'UNSPLASH_ACCESS_KEY',
    defaultValue: 'HiUWKVy1miiCu95gcST0H0O4wptuN6xbne25BW6gWUQ',
  );

  // Cloudinary: pass via --dart-define=CLOUDINARY_CLOUD_NAME=your_cloud_name
  static const String cloudinaryCloudName = String.fromEnvironment(
    'CLOUDINARY_CLOUD_NAME',
    defaultValue: 'diinayqrd',
  );

  // Create an "Unsigned" upload preset in Cloudinary Dashboard > Settings > Upload
  // Pass via --dart-define=CLOUDINARY_UPLOAD_PRESET=your_preset
  static const String cloudinaryUploadPreset = String.fromEnvironment(
    'CLOUDINARY_UPLOAD_PRESET',
    defaultValue: '',
  );

  static bool get useCloudinary =>
      cloudinaryCloudName.isNotEmpty && cloudinaryUploadPreset.isNotEmpty;
}
