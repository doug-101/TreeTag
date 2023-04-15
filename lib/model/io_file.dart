// io_file.dart, classes for handling storage and network file operations.
// TreeTag, an information storage program with an automatic tree structure.
// Copyright (c) 2023, Douglas W. Bell.
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
  Future<DateTime> get dataModTime;
  Future<DateTime> get fileModTime;
  Future<bool> get exists;

  Future<Map<String, dynamic>> readJson();
  Future<void> writeJson(Map<String, dynamic> data);
  Future<void> copyToPath(String newPath);
  Future<void> copyFromPath(String path);
  Future<void> rename(String newName);
  Future<void> delete();

  /// Copies this to the given object, can be local or network.
  Future<void> copyToFile(IOFile toFile) async {
    try {
      if (this is LocalFile && toFile is LocalFile) {
        await File(fullPath).copy(toFile.fullPath);
      } else {
        var data = await readJson();
        await toFile.writeJson(data);
      }
    } on FormatException catch (e) {
      throw HttpException(e.toString());
    } on IOException catch (e) {
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

  /// Returns the modified time stored in the file's data.
  @override
  Future<DateTime> get dataModTime async {
    var data = json.decode(await File(fullPath).readAsString());
    var seconds = data['properties']?['modtime'];
    DateTime time;
    if (seconds != null) {
      time = DateTime.fromMillisecondsSinceEpoch(seconds);
    } else {
      // Fall back to file system modified time if necessary.
      time = await File(fullPath).lastModified();
    }
    return time;
  }

  /// Returns the file system modified time (quicker than reading whole file).
  @override
  Future<DateTime> get fileModTime async => await File(fullPath).lastModified();

  @override
  Future<bool> get exists async => await File(fullPath).exists();

  /// Reads the file and returns the JSON objects.
  @override
  Future<Map<String, dynamic>> readJson() async {
    return json.decode(await File(fullPath).readAsString());
  }

  /// Reads a string file (for non-JSON files).
  Future<String> readString() async {
    return File(fullPath).readAsString();
  }

  /// Writes the JSON file.
  ///
  /// Raises a [SaveException] on error, caught in main source file.
  @override
  Future<void> writeJson(Map<String, dynamic> data) async {
    var dataString = json.encode(data);
    try {
      await File(fullPath).writeAsString(dataString);
    } on IOException catch (e) {
      throw SaveException(e.toString());
    }
  }

  /// Writes the string file (for non-JSON files).
  ///
  /// Raises a [SaveException] on error, caught in main source file.
  @override
  Future<void> writeString(String data) async {
    try {
      await File(fullPath).writeAsString(data);
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

  /// Return the full path to this object as needed by Kinto.
  ///
  /// Encode all special characters as needed for Kinto id's.
  @override
  String get fullPath {
    // Kinto only allows letters, numbers, _ and - in id's.
    // Convert all special characters to utf8 and percent-encoding,
    // then use _ and - in place of % and +.
    var name = Uri.encodeQueryComponent(filename)
        .replaceAll('.', '%2E')
        .replaceAll('~', '%7E')
        .replaceAll('_', '%5F')
        .replaceAll('-', '%2D')
        .replaceAll('%', '_')
        .replaceAll('+', '-');
    return [prefs.getString('netaddress') ?? '', 'collections', name].join('/');
  }

  String get recordPath => '$fullPath/records';

  @override
  Future<int> get fileSize async {
    int? size;
    // Use filter on 'filesize' filter to avoid retrieving entire file.
    var resp = await http.get(Uri.parse(recordPath + '?has_filesize=true'),
        headers: _networkHeader());
    if (resp.statusCode == 200) {
      var data = json.decode(resp.body)['data'];
      if (data != null && data.isNotEmpty) {
        size = data[0]['filesize'];
      }
    }
    return size ?? 0;
  }

  /// Returns the modified time stored in the file's data.
  @override
  Future<DateTime> get dataModTime async {
    int? seconds;
    // Use filter on 'modtime' filter to avoid retrieving entire file.
    var resp = await http.get(Uri.parse(recordPath + '?has_modtime=true'),
        headers: _networkHeader());
    if (resp.statusCode == 200) {
      var data = json.decode(resp.body)['data'];
      if (data != null && data.isNotEmpty) {
        seconds = data[0]['modtime'];
      }
      if (seconds == null) {
        // If no modtime property, fall back to Kinto network's time.
        resp = await http.get(Uri.parse(fullPath), headers: _networkHeader());
        if (resp.statusCode == 200) {
          seconds = json.decode(resp.body)['data']['last_modified'];
        }
      }
      if (seconds != null) {
        return DateTime.fromMillisecondsSinceEpoch(seconds);
      }
    }
    throw HttpException(resp.reasonPhrase ?? '');
  }

  /// Returns the Kinto network's modified time (quicker than reading JSON?)
  @override
  Future<DateTime> get fileModTime async {
    var resp = await http.get(Uri.parse(fullPath), headers: _networkHeader());
    if (resp.statusCode == 200) {
      var seconds = json.decode(resp.body)['data']['last_modified'];
      if (seconds != null) {
        return DateTime.fromMillisecondsSinceEpoch(seconds);
      }
    }
    throw HttpException(resp.reasonPhrase ?? '');
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
    var resp = await http.get(Uri.parse(recordPath + '?has_modtime=false'),
        headers: _networkHeader());
    if (resp.statusCode == 200) {
      var data = json.decode(resp.body)['data'];
      if (data != null && data.isNotEmpty) {
        return data[0];
      }
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
        var size = dataString.length;
        resp = await http.post(Uri.parse(recordPath),
            headers: _networkHeader(), body: dataString);
        if (resp.statusCode == 201) {
          var seconds = data['properties']?['modtime'] ??
              DateTime.now().millisecondsSinceEpoch;
          var metaData = {'filesize': size, 'modtime': seconds};
          var metaString = json.encode({'data': metaData});
          await http.post(Uri.parse(recordPath),
              headers: _networkHeader(), body: metaString);
        }
        return;
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
    try {
      var data = json.decode(await File(path).readAsString());
      await writeJson(data);
    } on FormatException catch (e) {
      throw HttpException(e.toString());
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
    var address = Uri.parse(
        [prefs.getString('netaddress') ?? '', 'collections'].join('/'));
    var resp = await http.get(address, headers: _networkHeader());
    if (resp.statusCode == 200) {
      var objList = json.decode(resp.body)['data'];
      if (objList != null) {
        for (var obj in objList) {
          var name = obj['id'];
          if (name != null) {
            // Removes all utf8, percent and unique encoding from [fullPath].
            var origName = Uri.decodeQueryComponent(
                name.replaceAll('-', '+').replaceAll('_', '%'));
            fileList.add(NetworkFile(origName));
          }
        }
      }
    } else {
      throw HttpException(resp.reasonPhrase ?? '');
    }
    return fileList;
  }
}

/// Change the user's password to [newPass].  Return true on success.
Future<bool> changeNetworkPassword(String newPass) async {
  var fullUri = Uri.parse(prefs.getString('netaddress') ?? '');
  var accountPath = [
    fullUri.origin,
    fullUri.pathSegments[0],
    'accounts',
    prefs.getString('netuser'),
  ].join('/');
  try {
    var resp = await http.put(Uri.parse(accountPath),
        headers: _networkHeader(), body: '{"data": {"password": "$newPass"}}');
    if (resp.statusCode == 200) return true;
  } on IOException {}
  return false;
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
