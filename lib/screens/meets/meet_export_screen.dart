import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import '../../models/meet_import_export_result.dart';
import '../../services/meet_import_export_service.dart';

class MeetExportScreen extends ConsumerStatefulWidget {
  final String eventId;
  final String meetName;

  const MeetExportScreen({
    required this.eventId,
    required this.meetName,
    Key? key,
  }) : super(key: key);

  @override
  ConsumerState<MeetExportScreen> createState() => _MeetExportScreenState();
}

class _MeetExportScreenState extends ConsumerState<MeetExportScreen> {
  late final MeetImportExportService _service;
  bool _isExporting = false;
  bool _isSharing = false;
  MeetExportResult? _exportResult;
  final GlobalKey _shareButtonKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _service = MeetImportExportService();
  }

  Future<void> _handleExport() async {
    setState(() => _isExporting = true);

    try {
      final result = await _service.exportMeet(widget.eventId);

      setState(() {
        _exportResult = result;
        _isExporting = false;
      });

      if (result.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.message),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.message),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      setState(() => _isExporting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Export error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _shareExportedFile() async {
    print('DEBUG: _shareExportedFile called');
    
    if (_exportResult?.filePath == null) {
      print('DEBUG: No file path in export result');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No file to save')),
      );
      return;
    }

    setState(() => _isSharing = true);

    try {
      final sourceFilePath = _exportResult!.filePath!;
      print('DEBUG: Attempting to save file: $sourceFilePath');
      
      final sourceFile = File(sourceFilePath);
      
      if (!await sourceFile.exists()) {
        print('DEBUG: File does not exist at path: $sourceFilePath');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('File no longer exists')),
          );
        }
        setState(() => _isSharing = false);
        return;
      }

      // Use file_picker to let user save directly (avoids share sheet creating extra .txt file)
      // Sanitize filename - remove special characters that aren't valid in filenames
      final sanitizedName = _exportResult!.meetName.replaceAll(RegExp(r'[^\w\s-]'), '').replaceAll(' ', '_');
      final fileName = 'meet_export_$sanitizedName.json';
      
      // Read the file bytes (required for Android & iOS)
      final bytes = await sourceFile.readAsBytes();
      print('DEBUG: Read ${bytes.length} bytes from source file');
      
      final outputPath = await FilePicker.platform.saveFile(
        dialogTitle: 'Save Meet Export',
        fileName: fileName,
        type: FileType.custom,
        allowedExtensions: ['json'],
        bytes: bytes, // Required for Android & iOS
      );

      if (outputPath == null) {
        // User cancelled
        print('DEBUG: User cancelled save');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Save cancelled')),
          );
        }
        setState(() => _isSharing = false);
        return;
      }

      print('DEBUG: File saved successfully to: $outputPath');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Meet exported successfully')),
        );
      }
    } catch (e, stackTrace) {
      print('DEBUG: Save error: $e');
      print('DEBUG: Stack trace: $stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Save error: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSharing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Export Meet'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Export Meet Data',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Meet: ${widget.meetName}',
                      style: const TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'This will export the complete meet structure including:',
                      style: TextStyle(fontSize: 14),
                    ),
                    const SizedBox(height: 8),
                    const Padding(
                      padding: EdgeInsets.only(left: 16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('• Sessions and events'),
                          Text('• Judge assignments'),
                          Text('• Fees and expenses'),
                          Text('• All associated data'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            if (_exportResult != null) ...[
              Card(
                color: _exportResult!.success ? Colors.green[50] : Colors.red[50],
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            _exportResult!.success ? Icons.check_circle : Icons.error,
                            color: _exportResult!.success ? Colors.green : Colors.red,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _exportResult!.message,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: _exportResult!.success ? Colors.green : Colors.red,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (_exportResult!.filePath != null) ...[
                        const SizedBox(height: 12),
                        SelectableText(
                          'File: ${_exportResult!.filePath}',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              if (_exportResult!.success && _exportResult!.filePath != null)
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        key: _shareButtonKey,
                        onPressed: _isSharing ? null : _shareExportedFile,
                        icon: _isSharing 
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.save),
                        label: Text(_isSharing ? 'Saving...' : 'Save File'),
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 24),
            ],
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isExporting ? null : _handleExport,
                icon: _isExporting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Icon(Icons.download),
                label: Text(
                  _isExporting ? 'Exporting...' : 'Export Meet',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
