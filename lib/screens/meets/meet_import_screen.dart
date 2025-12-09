import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:go_router/go_router.dart';
import '../../models/meet_import_export_result.dart';
import '../../services/meet_import_export_service.dart';
import '../../providers/event_provider.dart';

class MeetImportScreen extends ConsumerStatefulWidget {
  final String eventId;

  const MeetImportScreen({
    required this.eventId,
    Key? key,
  }) : super(key: key);

  @override
  ConsumerState<MeetImportScreen> createState() => _MeetImportScreenState();
}

class _MeetImportScreenState extends ConsumerState<MeetImportScreen> {
  late final MeetImportExportService _service;
  File? _selectedFile;
  bool _isImporting = false;
  MeetImportResult? _importResult;

  @override
  void initState() {
    super.initState();
    _service = MeetImportExportService();
  }

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result != null && result.files.single.path != null) {
        setState(() {
          _selectedFile = File(result.files.single.path!);
          _importResult = null;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error picking file: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _handleImport() async {
    if (_selectedFile == null) return;

    setState(() => _isImporting = true);

    try {
      final result = await _service.importMeet(_selectedFile!);

      setState(() {
        _importResult = result;
        _isImporting = false;
      });

      if (result.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.message),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
        // Could navigate back with success
        Future.delayed(const Duration(seconds: 1), () {
          Navigator.of(context).pop(result.meetId);
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.message),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      setState(() => _isImporting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Import error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Import Meet'),
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
                      'Import Meet Data',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Select a JSON file exported from Gymnastics Meet Expenses.',
                      style: TextStyle(fontSize: 14),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'The following will be imported:',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 8),
                    const Padding(
                      padding: EdgeInsets.only(left: 16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('• Meet information'),
                          Text('• Sessions and events'),
                          Text('• Judges and assignments'),
                          Text('• Fees and expenses'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            if (_selectedFile != null) ...[
              Card(
                color: Colors.blue[50],
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.description, color: Colors.blue),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _selectedFile!.path.split('/').last,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: _isImporting ? null : _pickFile,
                          child: const Text('Choose Different File'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
            if (_importResult != null) ...[
              Card(
                color: _importResult!.success ? Colors.green[50] : Colors.red[50],
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            _importResult!.success ? Icons.check_circle : Icons.error,
                            color: _importResult!.success ? Colors.green : Colors.red,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _importResult!.message,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: _importResult!.success ? Colors.green : Colors.red,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (_importResult!.success) ...[
                        const SizedBox(height: 16),
                        Text(
                          'Meet: ${_importResult!.meetName ?? 'Unknown'}',
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 8),
                        Text('Items imported:'),
                        const SizedBox(height: 8),
                        Padding(
                          padding: const EdgeInsets.only(left: 16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (_importResult!.sessionsCreated > 0)
                                Text('• Sessions: ${_importResult!.sessionsCreated}'),
                              if (_importResult!.floorsCreated > 0)
                                Text('• Floors: ${_importResult!.floorsCreated}'),
                              if (_importResult!.daysCreated > 0)
                                Text('• Days: ${_importResult!.daysCreated}'),
                              if (_importResult!.judgesCreated > 0)
                                Text('• Judges: ${_importResult!.judgesCreated}'),
                              if (_importResult!.assignmentsCreated > 0)
                                Text('• Assignments: ${_importResult!.assignmentsCreated}'),
                              if (_importResult!.feesCreated > 0)
                                Text('• Fees: ${_importResult!.feesCreated}'),
                              if (_importResult!.expensesCreated > 0)
                                Text('• Expenses: ${_importResult!.expensesCreated}'),
                            ],
                          ),
                        ),
                      ],
                      if (_importResult!.errors.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        const Text('Errors:'),
                        const SizedBox(height: 8),
                        ...List.generate(
                          _importResult!.errors.length,
                          (i) => Text('• ${_importResult!.errors[i]}'),
                        ),
                      ],
                      if (_importResult!.warnings.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        const Text('Warnings:'),
                        const SizedBox(height: 8),
                        ...List.generate(
                          _importResult!.warnings.length,
                          (i) => Text('• ${_importResult!.warnings[i]}'),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
            const Spacer(),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isImporting ? null : _pickFile,
                    child: const Text('Choose File'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: (_isImporting || _selectedFile == null) ? null : _handleImport,
                    icon: _isImporting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Icon(Icons.upload),
                    label: Text(
                      _isImporting ? 'Importing...' : 'Import Meet',
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
