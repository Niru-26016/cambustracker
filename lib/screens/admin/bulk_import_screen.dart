import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../services/bulk_import_service.dart';
import '../../services/firestore_service.dart';
import '../../models/driver_model.dart';
import '../../models/bus_model.dart';

/// Enum for import type
enum ImportType { drivers, buses }

/// Bulk Import Screen for importing drivers or buses from Excel/CSV
class BulkImportScreen extends StatefulWidget {
  final ImportType importType;

  const BulkImportScreen({super.key, required this.importType});

  @override
  State<BulkImportScreen> createState() => _BulkImportScreenState();
}

class _BulkImportScreenState extends State<BulkImportScreen> {
  final BulkImportService _importService = BulkImportService();
  final FirestoreService _firestoreService = FirestoreService();

  File? _selectedFile;
  String? _fileName;
  bool _isLoading = false;
  bool _isParsing = false;
  bool _isImporting = false;
  String? _templatePath;

  // Parsed data
  List<Driver> _parsedDrivers = [];
  List<Bus> _parsedBuses = [];
  List<Map<String, dynamic>> _rawData = [];
  List<String> _parseErrors = [];

  // Import results
  Map<String, dynamic>? _importResult;

  String get _title => widget.importType == ImportType.drivers
      ? 'Import Drivers'
      : 'Import Buses';

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;

    return Scaffold(
      appBar: AppBar(
        title: Text(_title),
        backgroundColor: Colors.transparent,
        foregroundColor: primaryColor,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Step 1: Download Template
            _buildStepCard(
              step: 1,
              title: 'Download Template',
              description: 'Download the Excel template with required columns',
              child: _buildDownloadTemplateButton(),
            ),
            const SizedBox(height: 16),

            // Step 2: Upload File
            _buildStepCard(
              step: 2,
              title: 'Upload File',
              description: 'Select your filled Excel (.xlsx) or CSV file',
              child: _buildFilePickerSection(),
            ),
            const SizedBox(height: 16),

            // Step 3: Preview Data
            if (_rawData.isNotEmpty || _parseErrors.isNotEmpty) ...[
              _buildStepCard(
                step: 3,
                title: 'Preview Data',
                description: 'Review the parsed data before importing',
                child: _buildPreviewSection(),
              ),
              const SizedBox(height: 16),
            ],

            // Step 4: Import
            if (_canImport) ...[
              _buildStepCard(
                step: 4,
                title: 'Import Data',
                description: 'Import the validated data to the system',
                child: _buildImportButton(),
              ),
              const SizedBox(height: 16),
            ],

            // Results
            if (_importResult != null) _buildResultsSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildStepCard({
    required int step,
    required String title,
    required String description,
    required Widget child,
  }) {
    return Card(
      color: const Color(0xFF1E1E1E),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.white.withOpacity(0.1)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '$step',
                      style: const TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        description,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.6),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildDownloadTemplateButton() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OutlinedButton.icon(
          onPressed: _isLoading ? null : _downloadTemplate,
          style: OutlinedButton.styleFrom(
            foregroundColor: Theme.of(context).primaryColor,
            side: BorderSide(color: Theme.of(context).primaryColor),
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
          icon: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.download),
          label: Text(_isLoading ? 'Generating...' : 'Download Template'),
        ),
        if (_templatePath != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.green.withOpacity(0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.check_circle,
                      color: Colors.green,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Template saved to Downloads!',
                        style: TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(
                      Icons.insert_drive_file,
                      color: Colors.green,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _templatePath!.split('/').last,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  '📱 Open your Files app → Downloads to find the template',
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildFilePickerSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          onTap: _isParsing ? null : _pickFile,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              border: Border.all(
                color: _selectedFile != null
                    ? Colors.green
                    : Theme.of(context).primaryColor.withOpacity(0.5),
                width: 2,
                style: BorderStyle.solid,
              ),
              borderRadius: BorderRadius.circular(12),
              color: _selectedFile != null
                  ? Colors.green.withOpacity(0.05)
                  : Colors.transparent,
            ),
            child: Column(
              children: [
                Icon(
                  _selectedFile != null
                      ? Icons.check_circle
                      : Icons.upload_file,
                  size: 48,
                  color: _selectedFile != null
                      ? Colors.green
                      : Theme.of(context).primaryColor.withOpacity(0.7),
                ),
                const SizedBox(height: 12),
                Text(
                  _selectedFile != null
                      ? _fileName ?? 'File selected'
                      : 'Tap to select file',
                  style: TextStyle(
                    color: _selectedFile != null
                        ? Colors.green
                        : Colors.white70,
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  'Supported: .xlsx, .csv',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.4),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_isParsing) ...[
          const SizedBox(height: 12),
          const LinearProgressIndicator(),
          const SizedBox(height: 8),
          const Text(
            'Parsing file...',
            style: TextStyle(color: Colors.white70),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }

  Widget _buildPreviewSection() {
    final itemCount = widget.importType == ImportType.drivers
        ? _parsedDrivers.length
        : _parsedBuses.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Summary
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              const Icon(Icons.info_outline, color: Colors.blue, size: 20),
              const SizedBox(width: 8),
              Text(
                '$itemCount valid item${itemCount == 1 ? '' : 's'} ready to import',
                style: const TextStyle(color: Colors.blue),
              ),
            ],
          ),
        ),

        // Errors
        if (_parseErrors.isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.warning_amber,
                      color: Colors.orange,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${_parseErrors.length} issue${_parseErrors.length == 1 ? '' : 's'} found:',
                      style: const TextStyle(
                        color: Colors.orange,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ...(_parseErrors
                    .take(5)
                    .map(
                      (error) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          '• $error',
                          style: const TextStyle(
                            color: Colors.orange,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    )),
                if (_parseErrors.length > 5)
                  Text(
                    '... and ${_parseErrors.length - 5} more',
                    style: const TextStyle(color: Colors.orange, fontSize: 12),
                  ),
              ],
            ),
          ),
        ],

        // Data Preview Table
        if (_rawData.isNotEmpty) ...[
          const SizedBox(height: 16),
          const Text(
            'Preview (first 5 rows):',
            style: TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: WidgetStateColor.resolveWith(
                (states) => Colors.white.withOpacity(0.1),
              ),
              columns: _buildTableColumns(),
              rows: _buildTableRows(),
            ),
          ),
        ],
      ],
    );
  }

  List<DataColumn> _buildTableColumns() {
    if (widget.importType == ImportType.drivers) {
      return const [
        DataColumn(
          label: Text('Row', style: TextStyle(color: Colors.white)),
        ),
        DataColumn(
          label: Text('Name', style: TextStyle(color: Colors.white)),
        ),
        DataColumn(
          label: Text('Phone', style: TextStyle(color: Colors.white)),
        ),
        DataColumn(
          label: Text('Bus', style: TextStyle(color: Colors.white)),
        ),
      ];
    } else {
      return const [
        DataColumn(
          label: Text('Row', style: TextStyle(color: Colors.white)),
        ),
        DataColumn(
          label: Text('Name', style: TextStyle(color: Colors.white)),
        ),
        DataColumn(
          label: Text('Number', style: TextStyle(color: Colors.white)),
        ),
      ];
    }
  }

  List<DataRow> _buildTableRows() {
    final previewData = _rawData.take(5).toList();
    return previewData.map((data) {
      if (widget.importType == ImportType.drivers) {
        return DataRow(
          cells: [
            DataCell(
              Text(
                '${data['row']}',
                style: const TextStyle(color: Colors.white70),
              ),
            ),
            DataCell(
              Text(
                data['name'] ?? '',
                style: const TextStyle(color: Colors.white),
              ),
            ),
            DataCell(
              Text(
                data['phone'] ?? '',
                style: const TextStyle(color: Colors.white),
              ),
            ),
            DataCell(
              Text(
                data['assignedBus'] ?? '-',
                style: TextStyle(
                  color: (data['assignedBus'] ?? '').isNotEmpty
                      ? Colors.green
                      : Colors.white54,
                ),
              ),
            ),
          ],
        );
      } else {
        return DataRow(
          cells: [
            DataCell(
              Text(
                '${data['row']}',
                style: const TextStyle(color: Colors.white70),
              ),
            ),
            DataCell(
              Text(
                data['name'] ?? '',
                style: const TextStyle(color: Colors.white),
              ),
            ),
            DataCell(
              Text(
                data['number'] ?? '',
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      }
    }).toList();
  }

  bool get _canImport {
    if (widget.importType == ImportType.drivers) {
      return _parsedDrivers.isNotEmpty && !_isImporting;
    } else {
      return _parsedBuses.isNotEmpty && !_isImporting;
    }
  }

  Widget _buildImportButton() {
    final itemCount = widget.importType == ImportType.drivers
        ? _parsedDrivers.length
        : _parsedBuses.length;

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _isImporting ? null : _importData,
        style: ElevatedButton.styleFrom(
          backgroundColor: Theme.of(context).primaryColor,
          foregroundColor: Colors.black,
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
        icon: _isImporting
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.black,
                ),
              )
            : const Icon(Icons.upload),
        label: Text(_isImporting ? 'Importing...' : 'Import $itemCount Items'),
      ),
    );
  }

  Widget _buildResultsSection() {
    final result = _importResult!;
    final success = result['successCount'] as int;
    final updated = result['updatedCount'] as int? ?? 0;
    final skipped = result['skippedCount'] as int;
    final failed = result['failedCount'] as int;
    final errors = result['errors'] as List<String>;

    return Card(
      color: (success > 0 || updated > 0)
          ? Colors.green.withOpacity(0.1)
          : Colors.red.withOpacity(0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: (success > 0 || updated > 0) ? Colors.green : Colors.red,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  (success > 0 || updated > 0)
                      ? Icons.check_circle
                      : Icons.error,
                  color: (success > 0 || updated > 0)
                      ? Colors.green
                      : Colors.red,
                ),
                const SizedBox(width: 8),
                Text(
                  'Import Complete',
                  style: TextStyle(
                    color: (success > 0 || updated > 0)
                        ? Colors.green
                        : Colors.red,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildResultRow('New imports', success, Colors.green),
            if (updated > 0)
              _buildResultRow('Updated existing', updated, Colors.blue),
            _buildResultRow('Skipped (no changes)', skipped, Colors.orange),
            _buildResultRow('Failed', failed, Colors.red),
            if (errors.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Divider(color: Colors.white24),
              const SizedBox(height: 8),
              const Text(
                'Details:',
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
              const SizedBox(height: 4),
              ...errors
                  .take(10)
                  .map(
                    (error) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        '• $error',
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
              if (errors.length > 10)
                Text(
                  '... and ${errors.length - 10} more',
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white70,
                  side: const BorderSide(color: Colors.white24),
                ),
                child: const Text('Done'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultRow(String label, int count, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white70)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '$count',
              style: TextStyle(color: color, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  // Actions
  Future<void> _downloadTemplate() async {
    setState(() => _isLoading = true);
    try {
      String path;
      if (widget.importType == ImportType.drivers) {
        path = await _importService.generateDriversTemplate();
      } else {
        path = await _importService.generateBusesTemplate();
      }
      setState(() => _templatePath = path);

      // Get just the filename for display
      final fileName = path.split('/').last;

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✓ $fileName saved to Downloads'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls', 'csv'],
      );

      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        setState(() {
          _selectedFile = file;
          _fileName = result.files.single.name;
          _isParsing = true;
          _importResult = null;
        });

        await _parseFile(file);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error picking file: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _parseFile(File file) async {
    try {
      if (widget.importType == ImportType.drivers) {
        final result = await _importService.parseDriversFromFile(file);
        setState(() {
          _parsedDrivers = result.items;
          _rawData = result.rawData;
          _parseErrors = result.errors;
          _isParsing = false;
        });
      } else {
        final result = await _importService.parseBusesFromFile(file);
        setState(() {
          _parsedBuses = result.items;
          _rawData = result.rawData;
          _parseErrors = result.errors;
          _isParsing = false;
        });
      }
    } catch (e) {
      setState(() {
        _parseErrors = ['Error parsing file: $e'];
        _isParsing = false;
      });
    }
  }

  Future<void> _importData() async {
    setState(() => _isImporting = true);
    try {
      Map<String, dynamic> result;
      if (widget.importType == ImportType.drivers) {
        // Extract bus assignments from raw data
        final Map<int, String> busAssignments = {};
        for (int i = 0; i < _rawData.length; i++) {
          final assignedBus = _rawData[i]['assignedBus'] as String?;
          if (assignedBus != null && assignedBus.isNotEmpty) {
            busAssignments[i] = assignedBus;
          }
        }

        result = await _firestoreService.bulkImportDrivers(
          _parsedDrivers,
          busAssignments: busAssignments.isNotEmpty ? busAssignments : null,
        );
      } else {
        // Convert Bus objects to maps for the service
        final busMaps = _parsedBuses
            .map(
              (b) => {'name': b.name ?? b.busNumber, 'busNumber': b.busNumber},
            )
            .toList();
        result = await _firestoreService.bulkImportBuses(busMaps);
      }
      setState(() => _importResult = result);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Import error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isImporting = false);
    }
  }
}
