# drift_duckdb

A [Drift](https://drift.simonbinder.eu/) database implementation for [DuckDB](https://duckdb.org/).

This package allows you to use DuckDB as a backend for your Drift databases in Dart and Flutter applications.

[简体中文](./README_ZH.md)

## Features

- **Drift Backend**: Seamlessly integrate DuckDB with the Drift ORM.
- **In-Memory & File-Based**: Supports both `:memory:` and local file storage.
- **Encrypted Databases**: Supports opening encrypted DuckDB files with an explicit encryption key.
- **Schema Versioning**: Built-in support for Drift's schema versioning.
- **Batched Statements**: Supports running multiple statements in a transaction.

## Getting started

Add `drift_duckdb` to your `pubspec.yaml`:

```yaml
dependencies:
  drift_duckdb: any
  drift: ^2.31.0
  dart_duckdb: ^1.4.4
```

Make sure you have the DuckDB dynamic library available on your system. For macOS users using Homebrew:
```dart
import 'package:dart_duckdb/open.dart';
// ...
open.overrideFor(OperatingSystem.macOS, '/opt/homebrew/lib/libduckdb.dylib');
```

## Usage

```dart
import 'package:drift/drift.dart';
import 'package:drift_duckdb/drift_duckdb.dart';

// Use an in-memory database
final executor = DuckdbQueryExecutor.inMemory();

// Or use a file-based database
// final executor = DuckdbQueryExecutor('path/to/my_database.db');

// Or open an encrypted DuckDB database
// final executor = DuckdbQueryExecutor(
//   'path/to/secure.duckdb',
//   encryption: const DuckdbEncryptionOptions(
//     key: 'replace-with-a-real-secret',
//   ),
// );

// Use it with your Drift database class
// final database = MyDriftDatabase(executor);
```

## Encrypted databases

DuckDB encryption is only available for file-based databases, so
`DuckdbQueryExecutor.inMemory()` does not accept encryption options.

```dart
final executor = DuckdbQueryExecutor(
  'path/to/secure.duckdb',
  encryption: const DuckdbEncryptionOptions(
    key: 'replace-with-a-real-secret',
    cipher: DuckdbEncryptionCipher.gcm,
  ),
);
```

Notes:

- This package opens encrypted databases by attaching the target file and then `USE`-ing it, so existing Drift SQL continues to work without schema qualification.
- The linked DuckDB native library must support encrypted storage. DuckDB 1.4+ is recommended.
- `LOAD httpfs` is **not** enabled automatically. If your deployment depends on the OpenSSL-backed implementation DuckDB documents for encryption performance, pass `loadHttpfs: true` explicitly to avoid hidden compatibility changes.
