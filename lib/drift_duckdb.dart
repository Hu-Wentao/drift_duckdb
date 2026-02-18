/// A drift database implementation for DuckDB.
library;

import 'dart:async';

import 'package:dart_duckdb/dart_duckdb.dart';
import 'package:drift/backends.dart';

class _DuckdbDelegate extends DatabaseDelegate {
  final String path;
  Database? db;
  Connection? conn;
  bool _isOpen = false;

  _DuckdbDelegate(this.path);

  @override
  late final DbVersionDelegate versionDelegate = _DuckdbVersionDelegate(this);

  @override
  TransactionDelegate get transactionDelegate => const NoTransactionDelegate();

  @override
  bool get isOpen => _isOpen;

  @override
  Future<void> open(QueryExecutorUser user) async {
    db = await duckdb.open(path);
    conn = await duckdb.connect(db!);
    _isOpen = true;
  }

  @override
  Future<void> close() async {
    await conn?.dispose();
    await db?.dispose();
    _isOpen = false;
  }

  Future<void> _execute(String statement, List<Object?> args) async {
    if (args.isEmpty) {
      await conn!.execute(statement);
    } else {
      final stmt = await conn!.prepare(statement);
      try {
        for (var i = 0; i < args.length; i++) {
          stmt.bind(args[i], i + 1);
        }
        await stmt.execute();
      } finally {
        await stmt.dispose();
      }
    }
  }

  Future<ResultSet> _query(String statement, List<Object?> args) async {
    if (args.isEmpty) {
      return await conn!.query(statement);
    } else {
      final stmt = await conn!.prepare(statement);
      try {
        for (var i = 0; i < args.length; i++) {
          stmt.bind(args[i], i + 1);
        }
        return await stmt.execute();
      } finally {
        await stmt.dispose();
      }
    }
  }

  @override
  Future<void> runCustom(String statement, List<Object?> args) async {
    await _execute(statement, args);
  }

  @override
  Future<int> runInsert(String statement, List<Object?> args) async {
    await _execute(statement, args);
    // DuckDB does not currently provide an easy way to get the last inserted
    // row ID or the number of affected rows from an execute call.
    return 0;
  }

  @override
  Future<QueryResult> runSelect(String statement, List<Object?> args) async {
    final result = await _query(statement, args);
    final columnNames = result.columnNames;
    final rows = result.fetchAll().map((row) {
      return Map<String, Object?>.fromIterables(columnNames, row);
    }).toList();
    return QueryResult.fromRows(rows);
  }

  @override
  Future<int> runUpdate(String statement, List<Object?> args) async {
    await _execute(statement, args);
    // DuckDB does not currently provide the number of affected rows from an
    // execute call in the Dart wrapper.
    return 0;
  }

  @override
  Future<void> runBatched(BatchedStatements statements) async {
    await conn!.execute('BEGIN TRANSACTION');
    try {
      for (final arg in statements.arguments) {
        await _execute(
          statements.statements[arg.statementIndex],
          arg.arguments,
        );
      }
      await conn!.execute('COMMIT');
    } catch (e) {
      await conn!.execute('ROLLBACK');
      rethrow;
    }
  }
}

class _DuckdbVersionDelegate extends DynamicVersionDelegate {
  final _DuckdbDelegate delegate;

  _DuckdbVersionDelegate(this.delegate);

  @override
  Future<int> get schemaVersion async {
    await _ensureTable();
    final result = await delegate.runSelect(
      'SELECT version FROM __drift_schema_version LIMIT 1;',
      [],
    );
    return result.rows.first.first as int;
  }

  @override
  Future<void> setSchemaVersion(int version) async {
    await _ensureTable();
    await delegate.runCustom('UPDATE __drift_schema_version SET version = ?;', [
      version,
    ]);
  }

  Future<void> _ensureTable() async {
    await delegate.runCustom(
      'CREATE TABLE IF NOT EXISTS __drift_schema_version (version INTEGER NOT NULL);',
      [],
    );
    final result = await delegate.runSelect(
      'SELECT COUNT(*) as count FROM __drift_schema_version;',
      [],
    );
    if (result.rows.first.first == 0) {
      await delegate.runCustom(
        'INSERT INTO __drift_schema_version (version) VALUES (0);',
        [],
      );
    }
  }
}

/// A query executor that uses the `dart_duckdb` package to connect to a DuckDB
/// database.
class DuckdbQueryExecutor extends DelegatedDatabase {
  /// Creates a query executor that will store the database in the file at [path].
  ///
  /// If [logStatements] is true, queries will be printed to the console.
  DuckdbQueryExecutor(String path, {bool? logStatements})
    : super(_DuckdbDelegate(path), logStatements: logStatements);

  /// Creates a query executor that will use an in-memory DuckDB database.
  DuckdbQueryExecutor.inMemory({bool? logStatements})
    : super(_DuckdbDelegate(':memory:'), logStatements: logStatements);

  /// The underlying [Database] object used by this executor.
  ///
  /// This will be null until the database has been opened.
  Database? get duckdbDb {
    final delegate = this.delegate as _DuckdbDelegate;
    return delegate.isOpen ? delegate.db : null;
  }

  /// The underlying [Connection] used by this executor.
  ///
  /// This will be null until the database has been opened.
  Connection? get connection {
    final delegate = this.delegate as _DuckdbDelegate;
    return delegate.isOpen ? delegate.conn : null;
  }

  @override
  bool get isSequential => true;
}
