// io_file.dart, classes for handling storage and network file operations.
// TreeTag, an information storage program with an automatic tree structure.
// Copyright (c) 2022, Douglas W. Bell.
// Free software, GPL v2 or later.

import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import '../main.dart' show prefs;

/// Interface definition for local and network files.
abstract class IOFile {
  final String filename;

  IOFile(this.filename);

  String get nameNoExtension => p.basenameWithoutExtension(filename);
  String get extension => p.extension(filename);
  String get fullPath;
  int get fileSize;
  String get lastModified;
  bool get exists;

  String readSync();
  Future<void> write(String data);
  Future<void> copyToPath(String newPath, {bool forceIfExists = false});
  Future<void> copyToFile(IOFile toFile, {bool forceIfExists = false});
  Future<void> rename(String newName, {bool forceIfExists = false});
  Future<void> delete();
}

class LocalFile extends IOFile {
  LocalFile(String filename) : super(filename);

  @override
  bool operator ==(Object other) =>
      other is LocalFile && filename == other.filename;
  @override
  int get hashCode => filename.hashCode;

  String get fullPath => p.join(prefs.getString('workdir')!, filename);

  int get fileSize => File(fullPath).statSync().size;

  String get lastModified => File(fullPath).lastModifiedSync().toString();

  bool get exists => File(fullPath).existsSync();

  String readSync() {
    return File(fullPath).readAsStringSync();
  }

  Future<void> write(String data) async {
    await File(fullPath).writeAsString(data);
  }

  Future<void> copyToPath(String newPath, {bool forceIfExists = false}) async {
    if (!forceIfExists && File(newPath).existsSync()) {
      throw FileExistsException('File $filename already exists.');
    }
    await File(fullPath).copy(newPath);
  }

  Future<void> copyToFile(IOFile toFile, {bool forceIfExists = false}) async {
    if (!forceIfExists && File(toFile.fullPath).existsSync()) {
      throw FileExistsException('File ${toFile.filename} already exists.');
    }
    await File(fullPath).copy(toFile.fullPath);
  }

  Future<void> rename(String newName, {bool forceIfExists = false}) async {
    var newFile = LocalFile(newName);
    if (!forceIfExists && newFile.exists) {
      throw FileExistsException('File $newName already exists.');
    }
    await File(fullPath).rename(newFile.fullPath);
  }

  Future<void> delete() async {
    await File(fullPath).delete();
  }

  static Future<List<IOFile>> fileList() async {
    var fileList = <LocalFile>[];
    await for (var entity in Directory(prefs.getString('workdir')!).list()) {
      if (entity != null && entity is File) {
        var baseName = p.basename(entity.path);
        if (!(prefs.getBool('hidedotfiles') ?? true) ||
            !baseName.startsWith('.')) {
          fileList.add(LocalFile(baseName));
        }
      }
    }
    return fileList;
  }

  static Future<LocalFile> copyFromPath(String path,
      {bool forceIfExists = false}) async {
    var newFile = LocalFile(p.basename(path));
    if (!forceIfExists && newFile.exists) {
      throw FileExistsException(newFile.filename);
    }
    await File(path).copy(newFile.fullPath);
    return newFile;
  }
}

class NetworkFile extends IOFile {
  NetworkFile(String filename) : super(filename);

  @override
  bool operator ==(Object other) =>
      other is NetworkFile && filename == other.filename;
  @override
  int get hashCode => filename.hashCode;

  String readSync() {
    return '';
  }

  String get fullPath => filename;

  int get fileSize => 0;

  String get lastModified => '';

  bool get exists => false;

  Future<void> write(String data) async {}

  Future<void> copyToPath(String newPath, {bool forceIfExists = false}) async {}

  Future<void> copyToFile(IOFile toFile, {bool forceIfExists = false}) async {}

  Future<void> rename(String newName, {bool forceIfExists = false}) async {}

  Future<void> delete() async {}

  static Future<List<IOFile>> fileList() async {
    var fileList = <NetworkFile>[];
    var address =
        Uri.parse('http://localhost:8888/v1/buckets/tt-doug/collections');
    var resp = await http.get(address, headers: _networkAuthHeader());
    if (resp.statusCode == 200) {
      var objList = json.decode(resp.body)['data'];
      if (objList != null) {
        for (var obj in objList) {
          var name = obj['id'];
          if (name != null) {
            fileList.add(NetworkFile(name));
          }
        }
      }
    }
    return fileList;
  }

  static Future<NetworkFile> copyFromPath(String path,
      {bool forceIfExists = false}) async {
    return NetworkFile('');
  }
}

Map<String, String> _networkAuthHeader() {
  return {'authorization': 'Basic ' + base64.encode(utf8.encode('doug:xxxx'))};
}

class FileExistsException implements Exception {
  final String? msg;

  const FileExistsException([this.msg]);

  @override
  String toString() => msg ?? 'FileExistsException';
}
