import 'dart:io';

void main() {
  final pubspec = File('pubspec.yaml');
  if (!pubspec.existsSync()) {
    print('pubspec.yaml not found');
    exit(1);
  }

  var content = pubspec.readAsStringSync();
  final versionRegex = RegExp(r'^version: (\d+\.\d+\.\d+)\+(\d+)$', multiLine: true);
  final match = versionRegex.firstMatch(content);

  if (match == null) {
    print('Version not found in pubspec.yaml');
    exit(1);
  }

  final versionName = match.group(1)!;
  final buildNumber = int.parse(match.group(2)!);
  final newBuildNumber = buildNumber + 1;
  final newVersion = '$versionName+$newBuildNumber';

  content = content.replaceFirst(
    'version: $versionName+$buildNumber',
    'version: $newVersion',
  );

  pubspec.writeAsStringSync(content);
  print('Version bumped: $versionName+$buildNumber → $newVersion');
}
