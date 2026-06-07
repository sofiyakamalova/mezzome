import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:mezzome/core/logging/app_logger.dart';
import 'package:path_provider/path_provider.dart';

enum MenuExportFormat { excel, word }

class MenuImportExportService {
  MenuImportExportService(this._dio);

  final Dio _dio;

  Future<void> importFile(BuildContext context, {required bool isWord}) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: isWord ? ['doc', 'docx'] : ['xls', 'xlsx', 'csv'],
    );
    if (result == null || result.files.isEmpty) {
      return;
    }
    final path = result.files.single.path;
    if (path == null) {
      return;
    }

    appLogger.i('Import selected: $path (${isWord ? 'word' : 'excel'})');

    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'importPendingBackend'.tr(
            namedArgs: {
              'file': result.files.single.name,
              'format': isWord ? 'Word' : 'Excel',
            },
          ),
        ),
      ),
    );
  }

  Future<void> exportMenu(
    BuildContext context, {
    required MenuExportFormat format,
    required Map<String, dynamic> payload,
  }) async {
    try {
      final response = await _dio.post<List<int>>(
        '/manager/reports/export',
        data: {
          'format': format == MenuExportFormat.excel ? 'xlsx' : 'docx',
          'report_type': 'menu_board',
          ...payload,
        },
        options: Options(responseType: ResponseType.bytes),
      );

      final bytes = response.data;
      if (bytes == null || bytes.isEmpty) {
        throw StateError('Empty export response');
      }

      final dir = await getTemporaryDirectory();
      final ext = format == MenuExportFormat.excel ? 'xlsx' : 'docx';
      final file = File(
        '${dir.path}/mezzome_menu_${DateTime.now().millisecondsSinceEpoch}.$ext',
      );
      await file.writeAsBytes(bytes);

      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'exportSaved'.tr(namedArgs: {'path': file.path}),
          ),
        ),
      );
    } catch (error) {
      appLogger.w('Export via API failed, generating local stub: $error');
      await _exportLocalStub(context, format: format, payload: payload);
    }
  }

  Future<void> _exportLocalStub(
    BuildContext context, {
    required MenuExportFormat format,
    required Map<String, dynamic> payload,
  }) async {
    final dir = await getTemporaryDirectory();
    final ext = format == MenuExportFormat.excel ? 'csv' : 'txt';
    final file = File('${dir.path}/mezzome_menu_export.$ext');
    final buffer = StringBuffer('MEZZOME Menu Export\n');
    buffer.writeln('format,${format.name}');
    buffer.writeln('generated,${DateTime.now().toIso8601String()}');
    buffer.writeln(jsonEncode(payload));
    await file.writeAsString(buffer.toString());

    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('exportLocalFallback'.tr(namedArgs: {'path': file.path})),
      ),
    );
  }
}

MenuImportExportService menuImportExportService(Dio dio) =>
    MenuImportExportService(dio);
