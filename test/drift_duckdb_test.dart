import 'package:dart_duckdb/dart_duckdb.dart';
import 'package:dart_duckdb/open.dart';
import 'package:drift/drift.dart' hide isNotNull;
import 'package:drift_duckdb/drift_duckdb.dart';
import 'package:test/test.dart';

void main() {
  // use for homebrew duckdb
  open.overrideFor(OperatingSystem.macOS, '/opt/homebrew/lib/libduckdb.dylib');
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
