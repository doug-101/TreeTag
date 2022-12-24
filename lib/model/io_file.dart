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

/// Interface definition for both local and network files.
abstract class IOFile {
  final String filename;

  IOFile(this.filename);

  /// Construct a [LocalFile] or a [NetworkFile] based on current preference.
  factory IOFile.currentType(String filename) {
    if (prefs.getBool('uselocalfiles') ?? true) {
      return LocalFile(filename);
    }
    return NetworkFile(filename);
  }

  String get nameNoExtension => p.basenameWithoutExtension(filename);
  String get extension => p.extension(filename);
  String get fullPath;
  Future<int> get fileSize;
  Future<DateTime> get lastModified;
  Future<bool> get exists;

  Future<Map<String, dynamic>> readJson();
  Future<void> writeJson(Map<String, dynamic> data);
  Future<void> copyToPath(String newPath);
  Future<void> copyFromPath(String path);
  Future<void> rename(String newName);
  Future<void> delete();

  /// Copies this to the fiven object, can be locl or network.
  Future<void> copyToFile(IOFile toFile) async {
    var data = await readJson();
    try {
      await toFile.writeJson(data);
    } on SaveException catch (e) {
      throw HttpException(e.toString());
    }
  }
}

/// A file that is in the working directory on the local drive.
class LocalFile extends IOFile {
  LocalFile(String filename) : super(filename);

  /// Allow comparisons and ordering.
  @override
  bool operator ==(Object other) =>
      other is LocalFile && filename == other.filename;
  @override
  int get hashCode => filename.hashCode;

  @override
  String get fullPath => p.join(prefs.getString('workdir')!, filename);

  @override
  Future<int> get fileSize async {
    var stat = await File(fullPath).stat();
    return stat.size;
  }

  @override
  Future<DateTime> get lastModified async {
    var time = await File(fullPath).lastModified();
    return time;
  }

  @override
  Future<bool> get exists async => await File(fullPath).exists();

  /// Reads the file and returns the JSON objects.
  @override
  Future<Map<String, dynamic>> readJson() async {
    return json.decode(await File(fullPath).readAsString());
  }

  /// Writes the file.
  ///
  /// Raises a [SaveException] on error, caught in main source file.
  @override
  Future<void> writeJson(Map<String, dynamic> data) async {
    var dataString = JsonEncoder.withIndent(' ').convert(data);
    try {
      await File(fullPath).writeAsString(dataString);
    } on IOException catch (e) {
      throw SaveException(e.toString());
    }
  }

  /// Copy this to an external drive path given by [newPath].
  @override
  Future<void> copyToPath(String newPath) async {
    await File(fullPath).copy(newPath);
  }

  /// Write this file using an external drive path given by [newPath].
  @override
  Future<void> copyFromPath(String path) async {
    await File(path).copy(fullPath);
  }

  /// Rename this object on disk.
  @override
  Future<void> rename(String newName) async {
    var newFile = LocalFile(newName);
    await File(fullPath).rename(newFile.fullPath);
  }

  /// Delete this object from disk.
  @override
  Future<void> delete() async {
    await File(fullPath).delete();
  }

  /// Return a directory listing of file objects.
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
}

/// A file that is in the network, uses a Kinto server.
class NetworkFile extends IOFile {
  static String password = '';

  NetworkFile(String filename) : super(filename);

  /// Allow comparisons and ordering.
  @override
  bool operator ==(Object other) =>
      other is NetworkFile && filename == other.filename;
  @override
  int get hashCode => filename.hashCode;

  /// Removes the file extension due to Kinto name limitations.
  @override
  String get fullPath => p.join(
      prefs.getString('netaddress') ?? '', 'collections', nameNoExtension);

  String get recordPath => p.join(fullPath, 'records');

  @override
  Future<int> get fileSize async => 0;

  @override
  Future<DateTime> get lastModified async {
    var resp = await http.get(Uri.parse(fullPath), headers: _networkHeader());
    var seconds = 0;
    if (resp.statusCode == 200) {
      seconds = json.decode(resp.body)['data']['last_modified'];
    }
    return DateTime.fromMillisecondsSinceEpoch(seconds);
  }

  @override
  Future<bool> get exists async {
    try {
      var resp = await http.get(Uri.parse(fullPath), headers: _networkHeader());
      return resp.statusCode == 200;
    } on IOException {
      return false;
    }
  }

  /// Reads the file and returns the JSON objects.
  @override
  Future<Map<String, dynamic>> readJson() async {
    var resp = await http.get(Uri.parse(recordPath), headers: _networkHeader());
    if (resp.statusCode == 200) {
      return json.decode(resp.body)['data'][0];
    }
    throw HttpException(resp.reasonPhrase ?? '');
  }

  /// Writes the file.
  ///
  /// Raises a [SaveException] on error, caught in main source file.
  @override
  Future<void> writeJson(Map<String, dynamic> data) async {
    try {
      var resp = await http.put(Uri.parse(fullPath), headers: _networkHeader());
      if (resp.statusCode == 200 || resp.statusCode == 201) {
        var dataString = json.encode({'data': data});
        resp = await http.post(Uri.parse(recordPath),
            headers: _networkHeader(), body: dataString);
        if (resp.statusCode == 201) {
          return;
        }
      }
      throw SaveException(resp.reasonPhrase ?? '');
    } on IOException catch (e) {
      throw SaveException(e.toString());
    }
  }

  /// Copy this to an external drive path given by [newPath].
  @override
  Future<void> copyToPath(String newPath) async {
    var data = await readJson();
    var dataString = JsonEncoder.withIndent(' ').convert(data);
    await File(newPath).writeAsString(dataString);
  }

  /// Write this file using an external drive path given by [newPath].
  @override
  Future<void> copyFromPath(String path) async {
    var data = json.decode(await File(path).readAsString());
    try {
      await writeJson(data);
    } on SaveException catch (e) {
      throw HttpException(e.toString());
    }
  }

  /// Copy this to a new name and delete the original.
  @override
  Future<void> rename(String newName) async {
    var data = await readJson();
    var newFile = NetworkFile(newName);
    try {
      await newFile.writeJson(data);
    } on SaveException catch (e) {
      throw HttpException(e.toString());
    }
    await delete();
  }

  /// Delete this object from the network.
  @override
  Future<void> delete() async {
    var resp =
        await http.delete(Uri.parse(fullPath), headers: _networkHeader());
    if (resp.statusCode != 200) {
      throw HttpException(resp.reasonPhrase ?? '');
    }
  }

  /// Return a directory listing of file objects.
  ///
  /// Adds the .trtg file extension back on.
  static Future<List<IOFile>> fileList() async {
    var fileList = <NetworkFile>[];
    var address =
        Uri.parse(p.join(prefs.getString('netaddress') ?? '', 'collections'));
    var resp = await http.get(address, headers: _networkHeader());
    if (resp.statusCode == 200) {
      var objList = json.decode(resp.body)['data'];
      if (objList != null) {
        for (var obj in objList) {
          var name = obj['id'];
          if (name != null) {
            fileList.add(NetworkFile('$name.trtg'));
          }
        }
      }
    } else {
      throw HttpException(resp.reasonPhrase ?? '');
    }
    return fileList;
  }
}

/// Return the authorization and content-type headers for Kinto.
Map<String, String> _networkHeader() {
  var authStr = '${prefs.getString('netuser') ?? ''}:${NetworkFile.password}';
  return {
    'authorization': 'Basic ' + base64.encode(utf8.encode(authStr)),
    'Content-Type': 'application/json',
  };
}

/// A unique exception for writing files, so it can be caught at the top level.
class SaveException extends IOException {
  final String? msg;

  SaveException([this.msg]);

  @override
  String toString() => msg ?? 'SaveException';
}
