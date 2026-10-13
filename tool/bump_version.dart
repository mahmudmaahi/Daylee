// Bumps the app version in pubspec.yaml and adds a changelog stub.
//
//   dart run tool/bump_version.dart patch   // 1.0.0+1 -> 1.0.1+2
//   dart run tool/bump_version.dart minor   // 1.0.1+2 -> 1.1.0+3
//   dart run tool/bump_version.dart major   // 1.1.0+3 -> 2.0.0+4
//   dart run tool/bump_version.dart build   // 1.1.0+3 -> 1.1.0+4
//
// The build number always increases by one: Android only installs an update
// when its versionCode is higher than the installed one.
import 'dart:io';

void main(List<String> args) {
  final kind = args.isEmpty ? '' : args.first;
  if (!const {'major', 'minor', 'patch', 'build'}.contains(kind)) {
    stderr.writeln(
      'Usage: dart run tool/bump_version.dart <major|minor|patch|build>',
    );
    exit(64);
  }

  final pubspec = File('pubspec.yaml');
  final text = pubspec.readAsStringSync();
  final match = RegExp(
    r'^version:\s*(\d+)\.(\d+)\.(\d+)\+(\d+)\s*$',
    multiLine: true,
  ).firstMatch(text);
  if (match == null) {
    stderr.writeln('Could not find "version: X.Y.Z+N" in pubspec.yaml');
    exit(65);
  }

  var major = int.parse(match.group(1)!);
  var minor = int.parse(match.group(2)!);
  var patch = int.parse(match.group(3)!);
  final build = int.parse(match.group(4)!) + 1;

  switch (kind) {
    case 'major':
      major++;
      minor = 0;
      patch = 0;
    case 'minor':
      minor++;
      patch = 0;
    case 'patch':
      patch++;
  }

  final next = '$major.$minor.$patch+$build';
  pubspec.writeAsStringSync(text.replaceFirst(match.group(0)!, 'version: $next'));

  final changelog = File('CHANGELOG.md');
  if (changelog.existsSync() && kind != 'build') {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final entry =
        '## [$major.$minor.$patch] - $today (build $build)\n\n'
        '### Added\n- \n\n### Changed\n- \n\n### Fixed\n- \n\n';
    final current = changelog.readAsStringSync();
    final marker = current.indexOf('\n## [');
    changelog.writeAsStringSync(
      marker < 0
          ? '$current\n$entry'
          : '${current.substring(0, marker + 1)}$entry${current.substring(marker + 1)}',
    );
  }

  stdout.writeln('Version is now $next');
}
