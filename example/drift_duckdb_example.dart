import 'package:dart_duckdb/dart_duckdb.dart';
import 'package:dart_duckdb/open.dart';
import 'package:drift/drift.dart';
import 'package:drift_duckdb/drift_duckdb.dart';

void main() async {
  // use for homebrew duckdb
  open.overrideFor(OperatingSystem.macOS, '/opt/homebrew/lib/libduckdb.dylib');

  // Use an in-memory database
  final executor = DuckdbQueryExecutor.inMemory(logStatements: true);

  // A drift-compatible QueryExecutor needs a user for opening
  final user = _User();
  await executor.ensureOpen(user);

  // Example of running custom statements
  await executor.runCustom('CREATE TABLE users (id INTEGER, name VARCHAR)', []);
  await executor.runCustom("INSERT INTO users VALUES (1, 'Alice')", []);
  await executor.runCustom("INSERT INTO users VALUES (2, 'Bob')", []);

  // Query the data
  // When calling runSelect on a drift executor, it returns a List<Map<String, Object?>>
  final result = await executor.runSelect('SELECT * FROM users', []);
  print('Found ${result.length} users:');
  for (final row in result) {
    print('  - ID: ${row['id']}, Name: ${row['name']}');
  }

  // Close resources
  await executor.close();
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
