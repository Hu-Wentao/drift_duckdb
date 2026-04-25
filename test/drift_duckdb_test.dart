import 'dart:io';

import 'package:dart_duckdb/dart_duckdb.dart';
import 'package:dart_duckdb/open.dart';
import 'package:drift/drift.dart' hide isNotNull;
import 'package:drift_duckdb/drift_duckdb.dart';
import 'package:test/test.dart';

void main() {
  // Prefer the checked-out local dylib used in this repository.
  // download it from https://duckdb.org/install/?platform=macos&environment=c&version=lts
  final localDuckdbLibrary =
      '${Directory.current.path}/data/'
      'libduckdb-osx-universal/libduckdb.dylib';
  if (File(localDuckdbLibrary).existsSync()) {
    open.overrideFor(OperatingSystem.macOS, localDuckdbLibrary);
  } else {
    // Fallback for developers who installed DuckDB with Homebrew.
    open.overrideFor(
      OperatingSystem.macOS,
      '/opt/homebrew/lib/libduckdb.dylib',
    );
  }
  group('DuckdbQueryExecutor', () {
    late DuckdbQueryExecutor executor;

    setUp(() {
      executor = DuckdbQueryExecutor.inMemory();
    });

    tearDown(() async {
      await executor.close();
    });

    test('can open connection', () async {
      await executor.ensureOpen(_User());
      expect(executor.duckdbDb, isNotNull);
      expect(executor.connection, isNotNull);
    });

    test('can execute queries', () async {
      await executor.ensureOpen(_User());
      await executor.runCustom('CREATE TABLE test (id INTEGER)', []);
      await executor.runCustom('INSERT INTO test VALUES (1)', []);

      final result = await executor.runSelect('SELECT * FROM test', []);
      expect(result, hasLength(1));
      expect(result.first['id'], 1);
    });

    test('schema versioning works', () async {
      final user = _User();
      await executor.ensureOpen(user);

      // Initial version should be 1 (from our _User)
      // Wait, drift's opening sequence handles this.
      // We can check the underlying table.
      final result = await executor.runSelect(
        'SELECT version FROM __drift_schema_version',
        [],
      );
      expect(result.first['version'], 1);
    });

    test('can reopen an encrypted database with the same key', () async {
      final directory = await Directory.systemTemp.createTemp(
        'drift_duckdb_encrypted_',
      );
      final path = '${directory.path}/encrypted.duckdb';
      const encryption = DuckdbEncryptionOptions(key: 'correct horse battery');

      var encryptedExecutor = DuckdbQueryExecutor(path, encryption: encryption);
      final wrongKeyExecutor = DuckdbQueryExecutor(
        path,
        encryption: const DuckdbEncryptionOptions(key: 'wrong key'),
      );
      final plainExecutor = DuckdbQueryExecutor(path);

      addTearDown(() async {
        await encryptedExecutor.close();
        await wrongKeyExecutor.close();
        await plainExecutor.close();
        await directory.delete(recursive: true);
      });

      await encryptedExecutor.ensureOpen(_User());
      await encryptedExecutor.runCustom('CREATE TABLE test (id INTEGER)', []);
      await encryptedExecutor.runCustom('INSERT INTO test VALUES (42)', []);
      await encryptedExecutor.close();
      encryptedExecutor = DuckdbQueryExecutor(path, encryption: encryption);

      await expectLater(
        wrongKeyExecutor.ensureOpen(_User()),
        throwsA(isA<DuckDBException>()),
      );
      await expectLater(
        plainExecutor.ensureOpen(_User()),
        throwsA(isA<DuckDBException>()),
      );

      await encryptedExecutor.ensureOpen(_User());
      final result = await encryptedExecutor.runSelect(
        'SELECT * FROM test',
        [],
      );
      expect(result, hasLength(1));
      expect(result.first['id'], 42);
    });
  });
}

class _User extends QueryExecutorUser {
  @override
  Future<void> beforeOpen(
    QueryExecutor executor,
    OpeningDetails details,
  ) async {}

  @override
  int get schemaVersion => 1;
}
