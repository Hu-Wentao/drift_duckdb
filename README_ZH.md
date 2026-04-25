# drift_duckdb (简体中文)

为 [DuckDB](https://duckdb.org/) 提供的 [Drift](https://drift.simonbinder.eu/) 数据库实现。

该软件包允许您在 Dart 和 Flutter 应用程序中将 DuckDB 作为 Drift 数据库的后端。

[English](./README.md)

## 特性

- **Drift 后端**: 将 DuckDB 与 Drift ORM 无缝集成。
- **内存与文件存储**: 支持 `:memory:` 和本地文件存储。
- **加密数据库**: 支持通过显式密钥打开加密的 DuckDB 文件。
- **模式版本管理**: 内置对 Drift 模式版本控制的支持。
- **批量执行**: 支持在事务中运行多个语句。

## 开始使用

将 `drift_duckdb` 添加到您的 `pubspec.yaml`：

```yaml
dependencies:
  drift_duckdb: any
  drift: ^2.31.0
  dart_duckdb: ^1.4.4
```

确保您的系统上提供了 DuckDB 动态库。对于使用 Homebrew 的 macOS 用户：
```dart
import 'package:dart_duckdb/open.dart';
// ...
open.overrideFor(OperatingSystem.macOS, '/opt/homebrew/lib/libduckdb.dylib');
```

## 使用方法

```dart
import 'package:drift/drift.dart';
import 'package:drift_duckdb/drift_duckdb.dart';

// 使用内存数据库
final executor = DuckdbQueryExecutor.inMemory();

// 或者使用基于文件的数据库
// final executor = DuckdbQueryExecutor('path/to/my_database.db');

// 或打开加密数据库
// final executor = DuckdbQueryExecutor(
//   'path/to/secure.duckdb',
//   encryption: const DuckdbEncryptionOptions(
//     key: 'replace-with-a-real-secret',
//   ),
// );

// 在您的 Drift 数据库类中使用它
// final database = MyDriftDatabase(executor);
```

## 加密数据库

DuckDB 的加密能力只适用于文件数据库，因此
`DuckdbQueryExecutor.inMemory()` 不接受加密参数。

```dart
final executor = DuckdbQueryExecutor(
  'path/to/secure.duckdb',
  encryption: const DuckdbEncryptionOptions(
    key: 'replace-with-a-real-secret',
    cipher: DuckdbEncryptionCipher.gcm,
  ),
);
```

说明：

- 这里的实现方式是先 `ATTACH` 加密文件，再执行 `USE` 切换到该库，因此现有 Drift 中未限定 schema 的 SQL 不需要改写。
- 运行时链接的 DuckDB 原生库必须支持加密存储，建议使用 DuckDB 1.4+。
- 不会默认执行 `LOAD httpfs`。如果你的部署依赖 DuckDB 文档中提到的基于 OpenSSL 的实现以获得更好的加密性能，请显式传入 `loadHttpfs: true`，避免引入隐藏兼容性变化。
