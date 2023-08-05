import 'package:test/test.dart';

import '__fixtures__/config.dart';
import '__fixtures__/file.dart';
import 'utils.dart';

void main() {
  group('lint_staged', () {
    test(
        'fails when task reverts staged changes without `--allow-empty`, to prevent an empty git commit',
        () async {
      final project = IntegrationProject();
      print('dir: ${project.path}');
      await project.setup();

      await project.fs.writeFile('pubspec.yaml', kConfigFormatFix);

      // Create and commit a pretty file without running lint_staged
      // This way the file will be available for the next step
      await project.fs.writeFile('lib/main.dart', kFormattedDart);
      await project.git.run(['add', '.']);
      await project.git.run(['commit', '-m committed pretty file']);

      // Edit file to be ugly
      await project.fs.removeFile('lib/main.dart');
      await project.fs.writeFile('lib/main.dart', kUnFormattedDart);
      await project.git.run(['add', 'lib/main.dart']);

      // Run lint_staged to automatically format the file
      // Since prettier reverts all changes, the commit should fail
      await expectLater(project.gitCommit(), throwsException);

      // Something was wrong so the repo is returned to original state
      expect(await project.git.stdout(['rev-list', '--count', 'HEAD']),
          equals('2'));
      expect(await project.git.stdout(['log', '-1', '--pretty=%B']),
          contains('committed pretty file'));
      expect(
          await project.fs.readFile('lib/main.dart'), equals(kUnFormattedDart));
    });

    test(
        'creates commit when task reverts staged changed and --allow-empty is used',
        () async {
      final project = IntegrationProject();
      print('dir: ${project.path}');
      await project.setup();

      await project.fs.writeFile('pubspec.yaml', kConfigFormatFix);

      // Create and commit a pretty file without running lint_staged
      // This way the file will be available for the next step
      await project.fs.writeFile('lib/main.dart', kFormattedDart);
      await project.git.run(['add', '.']);
      await project.git.run(['commit', '-m committed pretty file']);

      // Edit file to be unformatted
      await project.fs.removeFile('lib/main.dart');
      await project.fs.writeFile('lib/main.dart', kUnFormattedDart);
      await project.git.run(['add', 'lib/main.dart']);

      // Run lint_staged to automatically format the file
      // Here we also pass '--allow-empty' to gitCommit because this part is not the full lint_staged
      await expectLater(
          project.gitCommit(
              allowEmpty: true, gitCommitArgs: ['-m test', '--allow-empty']),
          completes);

      // Nothing was wrong so the empty commit is created
      expect(await project.git.stdout(['rev-list', '--count', 'HEAD']),
          equals('3'));
      expect(await project.git.stdout(['log', '-1', '--pretty=%B']),
          contains('test'));
      expect(await project.git.stdout(['diff', '-1']), equals(''));
      expect(
          await project.fs.readFile('lib/main.dart'), equals(kFormattedDart));
    });
  });
}
