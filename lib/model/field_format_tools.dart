// field_format_tools.dart, functions to work with field format strings.
// TreeTag, an information storage program with an automatic tree structure.
// Copyright (c) 2021, Douglas W. Bell.
// Free software, GPL v2 or later.

final numberFormatMap = const {
  '0': 'Required digit',
  '#': 'Optional digit',
  '.': 'Decimal separator',
  ',': 'Group separator',
  'E': 'Exponent separator',
  '+': 'Exponent sign',
};

final dateFormatMap = const {
  'yyyy': 'Year (4 digits)',
  'yy': 'Year (2 digits)',
  'MMMM': 'Month (full text)',
  'MMM': 'Month (abbrev. text)',
  'MM': 'Month (2 digits)',
  'M': 'Month (1 or 2 digits)',
  'dd': 'Day (2 digits)',
  'd': 'Day (1 or 2 digits)',
  'EEEE': 'Day of week (full text)',
  'EEE': 'Day of week (abbrev. text)',
  'D': 'Day of year (1 to 3 digits)',
  'G': 'Era (AD or BC)',
  'QQQ': 'Quarter (Q1, etc.)',
};

final timeFormatMap = const {
  'hh': 'Hour, 01-12 (2 digits)',
  'h': 'Hour, 1-12 (1 or 2 digits)',
  'HH': 'Hour, 00-23 (2 digits)',
  'H': 'Hour, 0-23 (1 or 2 digits)',
  'mm': 'Minute (2 digits)',
  'm': 'Minute (1 or 2 digits)',
  'ss': 'Second (2 digits)',
  's': 'Second (1 or 2 digits)',
  'S': 'Milliseconds (3 digits)',
  'a': 'AM/PM marker',
};

class FormatSegment {
  String? formatCode;
  String? extraText;

  FormatSegment({String? this.formatCode, String? this.extraText});
}

// Split a format, return segments with codes or extra text.
List<FormatSegment> parseFieldFormat(
    String format, Map<String, String> formatMap) {
  // Use null char to hande escaped (double) single quotes.
  format = format.replaceAll("''", "\x00");
  var result = <FormatSegment>[];
  while (format.isNotEmpty) {
    if (format[0] == "'") {
      var endPos = format.indexOf("'", 1);
      if (endPos < 0) throw FormatException('Expected closing quote');
      result.add(FormatSegment(
          extraText: format.substring(1, endPos).replaceAll("\x00", "'")));
      format = format.substring(endPos + 1);
    } else {
      var formatLen = format.length;
      for (var len = 4 <= format.length ? 4 : format.length; len > 0; len--) {
        if (formatMap.containsKey(format.substring(0, len))) {
          result.add(FormatSegment(formatCode: format.substring(0, len)));
          format = format.substring(len);
          break;
        }
      }
      if (formatLen == format.length) {
        var matchLen = RegExp(r"\W+").matchAsPrefix(format)?.end;
        if (matchLen != null && matchLen > 0) {
          result.add(FormatSegment(
              extraText:
                  format.substring(0, matchLen).replaceAll("\x00", "'")));
          format = format.substring(matchLen);
        } else {
          throw FormatException('Invalid format code');
        }
      }
    }
  }
  return result;
}

// Combine parsed format back into a single format string.
String combineFieldFormat(List<FormatSegment> parsedList,
    {bool condense = false}) {
  if (condense) {
    var condensedList = <FormatSegment>[];
    for (var segment in parsedList) {
      if (condensedList.isNotEmpty &&
          condensedList.last.extraText != null &&
          segment.extraText != null) {
        condensedList.last.extraText =
            condensedList.last.extraText! + segment.extraText!;
      } else {
        condensedList.add(segment);
      }
    }
    parsedList = condensedList;
  }
  var result = StringBuffer();
  for (var segment in parsedList) {
    if (segment.formatCode != null) {
      if (result.toString().endsWith(segment.formatCode![0]) &&
          segment.formatCode != '0' &&
          segment.formatCode != '#') {
        // Add a space to adjacent codes with the same letter to avoid garbage.
        result.write(' ');
      }
      result.write(segment.formatCode);
    } else {
      // Duplicate the single quotes to escape them.
      var text = segment.extraText!.replaceAll("'", "''");
      if (RegExp(r'\w').hasMatch(text)) {
        // Quotes required if alphabetic char are in text.
        result.write("'" + text + "'");
      } else {
        result.write(text);
      }
    }
  }
  return result.toString();
}

List<String> splitChoiceFormat(String format) {
  format = format.replaceAll(r'\/', '\x00');
  return [for (var s in format.split('/')) s.replaceAll('\x00', '/')];
}

String combineChoiceFormat(List<String> choices) {
  choices = [for (var s in choices) s.replaceAll('/', '\x00')];
  return choices.join('/').replaceAll('\x00', r'\/');
}

void main() {
  var list = parseFieldFormat("'Date''s is: 'MMMM d, ''yyyy", dateFormatMap);
  for (var s in list) {
    print('Code: ${s.formatCode}  Text: ${s.extraText}');
  }
  print('\n');
  print(combineFieldFormat(list));
}
