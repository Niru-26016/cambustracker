import 'dart:io';
import 'package:excel/excel.dart';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import '../models/driver_model.dart';
import '../models/bus_model.dart';

/// Result of a bulk import operation
class BulkImportResult {
  final int successCount;
  final int failedCount;
  final int skippedCount;
  final List<String> errors;

  BulkImportResult({
    required this.successCount,
    required this.failedCount,
    required this.skippedCount,
    required this.errors,
  });

  bool get hasErrors => errors.isNotEmpty;
  int get totalProcessed => successCount + failedCount + skippedCount;
}

/// Parsed data from a file before import
class ParsedImportData<T> {
  final List<T> items;
  final List<String> errors;
  final List<Map<String, dynamic>> rawData;

  ParsedImportData({
    required this.items,
    required this.errors,
    required this.rawData,
  });

  bool get hasErrors => errors.isNotEmpty;
  bool get isEmpty => items.isEmpty;
}

/// Service for handling bulk import of drivers and buses
class BulkImportService {
  /// Parse drivers from an Excel or CSV file
  Future<ParsedImportData<Driver>> parseDriversFromFile(File file) async {
    final extension = file.path.split('.').last.toLowerCase();

    if (extension == 'xlsx' || extension == 'xls') {
      return _parseDriversFromExcel(file);
    } else if (extension == 'csv') {
      return _parseDriversFromCsv(file);
    } else {
      return ParsedImportData(
        items: [],
        errors: ['Unsupported file format. Please use .xlsx or .csv'],
        rawData: [],
      );
    }
  }

  /// Parse buses from an Excel or CSV file
  Future<ParsedImportData<Bus>> parseBusesFromFile(File file) async {
    final extension = file.path.split('.').last.toLowerCase();

    if (extension == 'xlsx' || extension == 'xls') {
      return _parseBusesFromExcel(file);
    } else if (extension == 'csv') {
      return _parseBusesFromCsv(file);
    } else {
      return ParsedImportData(
        items: [],
        errors: ['Unsupported file format. Please use .xlsx or .csv'],
        rawData: [],
      );
    }
  }

  /// Parse drivers from Excel file
  Future<ParsedImportData<Driver>> _parseDriversFromExcel(File file) async {
    try {
      final bytes = await file.readAsBytes();
      final excel = Excel.decodeBytes(bytes);

      final sheet = excel.tables.values.first;
      if (sheet.rows.isEmpty) {
        return ParsedImportData(
          items: [],
          errors: ['File is empty'],
          rawData: [],
        );
      }

      // Get headers from first row
      final headers = sheet.rows.first
          .map((cell) => cell?.value?.toString().toLowerCase().trim() ?? '')
          .toList();

      final nameIdx = _findHeaderIndex(headers, [
        'name',
        'driver name',
        'driver',
      ]);
      final emailIdx = _findHeaderIndex(headers, ['email', 'e-mail', 'mail']);
      final phoneIdx = _findHeaderIndex(headers, [
        'phone',
        'mobile',
        'contact',
        'phone number',
      ]);
      final busIdx = _findHeaderIndex(headers, [
        'assigned bus',
        'bus',
        'bus number',
        'bus name',
      ]);

      if (nameIdx == -1) {
        return ParsedImportData(
          items: [],
          errors: ['Could not find "Name" column in the file'],
          rawData: [],
        );
      }

      final List<Driver> drivers = [];
      final List<String> errors = [];
      final List<Map<String, dynamic>> rawData = [];

      for (int i = 1; i < sheet.rows.length; i++) {
        final row = sheet.rows[i];
        if (row.every(
          (cell) =>
              cell?.value == null || cell!.value.toString().trim().isEmpty,
        )) {
          continue; // Skip empty rows
        }

        final name = _getCellValue(row, nameIdx);
        final email = _getCellValue(row, emailIdx);
        final phone = _getCellValue(row, phoneIdx);
        final assignedBus = _getCellValue(row, busIdx);

        rawData.add({
          'name': name,
          'email': email,
          'phone': phone,
          'assignedBus': assignedBus,
          'row': i + 1,
        });

        // Validate required fields
        if (name.isEmpty) {
          errors.add('Row ${i + 1}: Name is required');
          continue;
        }
        if (phone.isEmpty) {
          errors.add('Row ${i + 1}: Phone number is required');
          continue;
        }

        // Validate phone format (10 digits only)
        final cleanPhone = phone.replaceAll(RegExp(r'[^0-9]'), '');
        if (cleanPhone.length != 10) {
          errors.add(
            'Row ${i + 1}: Phone must be 10 digits (got ${cleanPhone.length})',
          );
          continue;
        }

        // Validate email format if provided
        if (email.isNotEmpty && !_isValidEmail(email)) {
          errors.add('Row ${i + 1}: Invalid email format "$email"');
          continue;
        }

        drivers.add(
          Driver(
            driverId: '', // Will be generated by Firestore
            userId: '',
            name: name,
            email: email,
            phone: cleanPhone,
            isActive: true,
            createdAt: DateTime.now(),
          ),
        );
      }

      return ParsedImportData(items: drivers, errors: errors, rawData: rawData);
    } catch (e) {
      return ParsedImportData(
        items: [],
        errors: ['Error parsing Excel file: $e'],
        rawData: [],
      );
    }
  }

  /// Parse drivers from CSV file
  Future<ParsedImportData<Driver>> _parseDriversFromCsv(File file) async {
    try {
      final content = await file.readAsString();
      final rows = const CsvToListConverter().convert(content);

      if (rows.isEmpty) {
        return ParsedImportData(
          items: [],
          errors: ['File is empty'],
          rawData: [],
        );
      }

      // Get headers from first row
      final headers = rows.first
          .map((e) => e.toString().toLowerCase().trim())
          .toList();

      final nameIdx = _findHeaderIndex(headers, [
        'name',
        'driver name',
        'driver',
      ]);
      final emailIdx = _findHeaderIndex(headers, ['email', 'e-mail', 'mail']);
      final phoneIdx = _findHeaderIndex(headers, [
        'phone',
        'mobile',
        'contact',
        'phone number',
      ]);
      final busIdx = _findHeaderIndex(headers, [
        'assigned bus',
        'bus',
        'bus number',
        'bus name',
      ]);

      if (nameIdx == -1) {
        return ParsedImportData(
          items: [],
          errors: ['Could not find "Name" column in the file'],
          rawData: [],
        );
      }

      final List<Driver> drivers = [];
      final List<String> errors = [];
      final List<Map<String, dynamic>> rawData = [];

      for (int i = 1; i < rows.length; i++) {
        final row = rows[i];
        if (row.every((cell) => cell.toString().trim().isEmpty)) {
          continue; // Skip empty rows
        }

        final name = _getListValue(row, nameIdx);
        final email = _getListValue(row, emailIdx);
        final phone = _getListValue(row, phoneIdx);
        final assignedBus = _getListValue(row, busIdx);

        rawData.add({
          'name': name,
          'email': email,
          'phone': phone,
          'assignedBus': assignedBus,
          'row': i + 1,
        });

        // Validate required fields
        if (name.isEmpty) {
          errors.add('Row ${i + 1}: Name is required');
          continue;
        }
        if (phone.isEmpty) {
          errors.add('Row ${i + 1}: Phone number is required');
          continue;
        }

        // Validate phone format (10 digits only)
        final cleanPhone = phone.replaceAll(RegExp(r'[^0-9]'), '');
        if (cleanPhone.length != 10) {
          errors.add(
            'Row ${i + 1}: Phone must be 10 digits (got ${cleanPhone.length})',
          );
          continue;
        }

        // Validate email format if provided
        if (email.isNotEmpty && !_isValidEmail(email)) {
          errors.add('Row ${i + 1}: Invalid email format "$email"');
          continue;
        }

        drivers.add(
          Driver(
            driverId: '',
            userId: '',
            name: name,
            email: email,
            phone: cleanPhone,
            isActive: true,
            createdAt: DateTime.now(),
          ),
        );
      }

      return ParsedImportData(items: drivers, errors: errors, rawData: rawData);
    } catch (e) {
      return ParsedImportData(
        items: [],
        errors: ['Error parsing CSV file: $e'],
        rawData: [],
      );
    }
  }

  /// Parse buses from Excel file
  Future<ParsedImportData<Bus>> _parseBusesFromExcel(File file) async {
    try {
      final bytes = await file.readAsBytes();
      final excel = Excel.decodeBytes(bytes);

      final sheet = excel.tables.values.first;
      if (sheet.rows.isEmpty) {
        return ParsedImportData(
          items: [],
          errors: ['File is empty'],
          rawData: [],
        );
      }

      // Get headers from first row
      final headers = sheet.rows.first
          .map((cell) => cell?.value?.toString().toLowerCase().trim() ?? '')
          .toList();

      final nameIdx = _findHeaderIndex(headers, ['name', 'bus name', 'bus']);
      final numberIdx = _findHeaderIndex(headers, [
        'number',
        'bus number',
        'registration',
        'reg no',
      ]);

      if (nameIdx == -1 && numberIdx == -1) {
        return ParsedImportData(
          items: [],
          errors: ['Could not find "Name" or "Bus Number" column in the file'],
          rawData: [],
        );
      }

      final List<Bus> buses = [];
      final List<String> errors = [];
      final List<Map<String, dynamic>> rawData = [];

      for (int i = 1; i < sheet.rows.length; i++) {
        final row = sheet.rows[i];
        if (row.every(
          (cell) =>
              cell?.value == null || cell!.value.toString().trim().isEmpty,
        )) {
          continue; // Skip empty rows
        }

        final name = _getCellValue(row, nameIdx);
        final number = _getCellValue(row, numberIdx);

        rawData.add({'name': name, 'number': number, 'row': i + 1});

        // Validate - need at least name or number
        if (name.isEmpty && number.isEmpty) {
          errors.add('Row ${i + 1}: Bus Name or Bus Number is required');
          continue;
        }

        final busNumber = number.isNotEmpty
            ? number
            : 'BUS-${DateTime.now().millisecondsSinceEpoch % 10000}-$i';
        final busName = name.isNotEmpty ? '$name ($busNumber)' : busNumber;

        buses.add(
          Bus(
            busId: '', // Will be generated
            busNumber: busNumber,
            name: busName,
            isActive: false,
            createdAt: DateTime.now(),
          ),
        );
      }

      return ParsedImportData(items: buses, errors: errors, rawData: rawData);
    } catch (e) {
      return ParsedImportData(
        items: [],
        errors: ['Error parsing Excel file: $e'],
        rawData: [],
      );
    }
  }

  /// Parse buses from CSV file
  Future<ParsedImportData<Bus>> _parseBusesFromCsv(File file) async {
    try {
      final content = await file.readAsString();
      final rows = const CsvToListConverter().convert(content);

      if (rows.isEmpty) {
        return ParsedImportData(
          items: [],
          errors: ['File is empty'],
          rawData: [],
        );
      }

      // Get headers from first row
      final headers = rows.first
          .map((e) => e.toString().toLowerCase().trim())
          .toList();

      final nameIdx = _findHeaderIndex(headers, ['name', 'bus name', 'bus']);
      final numberIdx = _findHeaderIndex(headers, [
        'number',
        'bus number',
        'registration',
        'reg no',
      ]);

      if (nameIdx == -1 && numberIdx == -1) {
        return ParsedImportData(
          items: [],
          errors: ['Could not find "Name" or "Bus Number" column in the file'],
          rawData: [],
        );
      }

      final List<Bus> buses = [];
      final List<String> errors = [];
      final List<Map<String, dynamic>> rawData = [];

      for (int i = 1; i < rows.length; i++) {
        final row = rows[i];
        if (row.every((cell) => cell.toString().trim().isEmpty)) {
          continue; // Skip empty rows
        }

        final name = _getListValue(row, nameIdx);
        final number = _getListValue(row, numberIdx);

        rawData.add({'name': name, 'number': number, 'row': i + 1});

        // Validate - need at least name or number
        if (name.isEmpty && number.isEmpty) {
          errors.add('Row ${i + 1}: Bus Name or Bus Number is required');
          continue;
        }

        final busNumber = number.isNotEmpty
            ? number
            : 'BUS-${DateTime.now().millisecondsSinceEpoch % 10000}-$i';
        final busName = name.isNotEmpty ? '$name ($busNumber)' : busNumber;

        buses.add(
          Bus(
            busId: '',
            busNumber: busNumber,
            name: busName,
            isActive: false,
            createdAt: DateTime.now(),
          ),
        );
      }

      return ParsedImportData(items: buses, errors: errors, rawData: rawData);
    } catch (e) {
      return ParsedImportData(
        items: [],
        errors: ['Error parsing CSV file: $e'],
        rawData: [],
      );
    }
  }

  /// Generate drivers template Excel file - saves to Downloads folder
  Future<String> generateDriversTemplate() async {
    final excel = Excel.createExcel();
    final sheet = excel['Drivers'];

    // Headers
    sheet.appendRow([
      TextCellValue('Name'),
      TextCellValue('Email'),
      TextCellValue('Phone'),
      TextCellValue('Bus Number'),
    ]);

    // Sample data
    sheet.appendRow([
      TextCellValue('John Doe'),
      TextCellValue('john@example.com'),
      TextCellValue('9876543210'),
      TextCellValue('69'),
    ]);
    sheet.appendRow([
      TextCellValue('Jane Smith'),
      TextCellValue('jane@example.com'),
      TextCellValue('9876543211'),
      TextCellValue('56'),
    ]);

    // Remove default Sheet1 if it exists
    if (excel.tables.containsKey('Sheet1')) {
      excel.delete('Sheet1');
    }

    // Save to Downloads folder
    final filePath = await _getDownloadsPath('drivers_template.xlsx');
    final file = File(filePath);
    await file.writeAsBytes(excel.encode()!);

    return filePath;
  }

  /// Generate buses template Excel file - saves to Downloads folder
  Future<String> generateBusesTemplate() async {
    final excel = Excel.createExcel();
    final sheet = excel['Buses'];

    // Headers
    sheet.appendRow([TextCellValue('Bus Name'), TextCellValue('Bus Number')]);

    // Sample data
    sheet.appendRow([
      TextCellValue('Campus Express'),
      TextCellValue('BUS-001'),
    ]);
    sheet.appendRow([TextCellValue('North Shuttle'), TextCellValue('BUS-002')]);

    // Remove default Sheet1 if it exists
    if (excel.tables.containsKey('Sheet1')) {
      excel.delete('Sheet1');
    }

    // Save to Downloads folder
    final filePath = await _getDownloadsPath('buses_template.xlsx');
    final file = File(filePath);
    await file.writeAsBytes(excel.encode()!);

    return filePath;
  }

  /// Get path in Downloads folder (works on Android)
  Future<String> _getDownloadsPath(String fileName) async {
    // Try to get the external storage Downloads folder
    if (Platform.isAndroid) {
      // On Android, use the public Downloads directory
      final downloadsDir = Directory('/storage/emulated/0/Download');
      if (await downloadsDir.exists()) {
        return '${downloadsDir.path}/$fileName';
      }
    }
    // Fallback to app documents directory
    final directory = await getApplicationDocumentsDirectory();
    return '${directory.path}/$fileName';
  }

  // Helper methods
  int _findHeaderIndex(List<String> headers, List<String> possibleNames) {
    for (final name in possibleNames) {
      final idx = headers.indexOf(name);
      if (idx != -1) return idx;
    }
    return -1;
  }

  String _getCellValue(List<Data?> row, int index) {
    if (index == -1 || index >= row.length) return '';
    return row[index]?.value?.toString().trim() ?? '';
  }

  String _getListValue(List<dynamic> row, int index) {
    if (index == -1 || index >= row.length) return '';
    return row[index].toString().trim();
  }

  /// Validate email format using regex
  bool _isValidEmail(String email) {
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );
    return emailRegex.hasMatch(email);
  }
}
