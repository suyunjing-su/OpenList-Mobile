import 'dart:io';
import 'dart:developer';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:get/get.dart' as getx;
import 'package:flutter/material.dart';

class DownloadManager {
  static final Dio _dio = Dio();
  
  /// 直接下载文件到系统下载目录
  static Future<bool> downloadFile({
    required String url,
    String? filename,
    Function(int received, int total)? onProgress,
  }) async {
    try {
      // 请求存储权限
      if (Platform.isAndroid) {
        // Android 11+ 需要管理外部存储权限
        var storageStatus = await Permission.storage.status;
        var manageStorageStatus = await Permission.manageExternalStorage.status;
        
        if (!storageStatus.isGranted) {
          storageStatus = await Permission.storage.request();
        }
        
        if (!manageStorageStatus.isGranted) {
          manageStorageStatus = await Permission.manageExternalStorage.request();
        }
        
        // 如果都没有权限，提示用户
        if (!storageStatus.isGranted && !manageStorageStatus.isGranted) {
          getx.Get.showSnackbar(getx.GetSnackBar(
            message: '需要存储权限才能下载文件，请在设置中手动授权',
            duration: const Duration(seconds: 5),
            mainButton: TextButton(
              onPressed: () {
                openAppSettings();
              },
              child: const Text('去设置'),
            ),
          ));
          return false;
        }
      }

      // 获取下载目录并创建OpenList专用文件夹
      Directory? downloadDir = await _getOpenListDownloadDirectory();

      if (downloadDir == null) {
        getx.Get.showSnackbar(const getx.GetSnackBar(
          message: '无法获取下载目录',
          duration: Duration(seconds: 3),
        ));
        return false;
      }

      // 确定文件名
      String finalFilename = filename ?? _getFilenameFromUrl(url);
      String filePath = '${downloadDir.path}/$finalFilename';

      // 检查文件是否已存在，如果存在则添加序号
      filePath = _getUniqueFilePath(filePath);

      log('开始下载文件: $url');
      log('保存路径: $filePath');

      // 显示下载开始提示
      getx.Get.showSnackbar(getx.GetSnackBar(
        message: '开始下载: $finalFilename',
        duration: const Duration(seconds: 2),
      ));

      // 执行下载
      await _dio.download(
        url,
        filePath,
        onReceiveProgress: (received, total) {
          if (onProgress != null) {
            onProgress(received, total);
          }
          
          // 显示下载进度
          if (total > 0) {
            double progress = received / total;
            log('下载进度: ${(progress * 100).toStringAsFixed(1)}%');
          }
        },
      );

      // 下载完成提示
      getx.Get.showSnackbar(getx.GetSnackBar(
        message: '下载完成: $finalFilename',
        duration: const Duration(seconds: 3),
        mainButton: TextButton(
          onPressed: () {
            _openFile(filePath);
          },
          child: const Text('打开'),
        ),
      ));

      log('文件下载完成: $filePath');
      return true;

    } catch (e) {
      log('下载失败: $e');
      getx.Get.showSnackbar(getx.GetSnackBar(
        message: '下载失败: ${e.toString()}',
        duration: const Duration(seconds: 3),
      ));
      return false;
    }
  }

  /// 获取OpenList专用下载目录
  static Future<Directory?> _getOpenListDownloadDirectory() async {
    try {
      Directory? baseDir;
      
      if (Platform.isAndroid) {
        // Android: 优先使用公共下载目录
        baseDir = Directory('/storage/emulated/0/Download');
        if (!await baseDir.exists()) {
          // 如果公共下载目录不存在，使用外部存储目录
          baseDir = await getExternalStorageDirectory();
          if (baseDir != null) {
            baseDir = Directory('${baseDir.path}/Download');
          }
        }
      } else if (Platform.isIOS) {
        // iOS: 使用应用文档目录下的Downloads文件夹
        baseDir = await getApplicationDocumentsDirectory();
        if (baseDir != null) {
          baseDir = Directory('${baseDir.path}/Downloads');
        }
      } else {
        // 其他平台（如Windows、macOS、Linux）
        baseDir = await getDownloadsDirectory();
      }

      if (baseDir == null) {
        log('无法获取基础下载目录');
        return null;
      }

      // 创建OpenList专用文件夹
      Directory openListDir = Directory('${baseDir.path}/OpenList');
      
      if (!await openListDir.exists()) {
        try {
          await openListDir.create(recursive: true);
          log('创建OpenList下载目录: ${openListDir.path}');
        } catch (e) {
          log('创建OpenList目录失败: $e');
          // 如果创建失败，返回基础目录
          return baseDir;
        }
      }

      log('OpenList下载目录: ${openListDir.path}');
      return openListDir;
      
    } catch (e) {
      log('获取下载目录失败: $e');
      return null;
    }
  }

  /// 从URL中提取文件名
  static String _getFilenameFromUrl(String url) {
    try {
      Uri uri = Uri.parse(url);
      String path = uri.path;
      if (path.isNotEmpty && path.contains('/')) {
        String filename = path.split('/').last;
        if (filename.isNotEmpty) {
          return filename;
        }
      }
    } catch (e) {
      log('解析文件名失败: $e');
    }
    
    // 如果无法从URL提取文件名，使用时间戳
    return 'download_${DateTime.now().millisecondsSinceEpoch}';
  }

  /// 获取唯一的文件路径（避免重名）
  static String _getUniqueFilePath(String originalPath) {
    File file = File(originalPath);
    if (!file.existsSync()) {
      return originalPath;
    }

    String directory = file.parent.path;
    String nameWithoutExtension = file.path.split('/').last.split('.').first;
    String extension = file.path.contains('.') 
        ? '.${file.path.split('.').last}' 
        : '';

    int counter = 1;
    String newPath;
    do {
      newPath = '$directory/${nameWithoutExtension}_$counter$extension';
      counter++;
    } while (File(newPath).existsSync());

    return newPath;
  }

  /// 尝试打开文件
  static void _openFile(String filePath) {
    try {
      if (Platform.isAndroid) {
        // 在Android上，使用Intent打开文件
        Process.run('am', [
          'start',
          '-a', 'android.intent.action.VIEW',
          '-d', 'file://$filePath',
          '-t', _getMimeType(filePath),
        ]);
      } else if (Platform.isIOS) {
        // iOS上显示文件位置提示，因为iOS应用沙盒限制
        getx.Get.showSnackbar(getx.GetSnackBar(
          message: '文件已保存到应用文档目录',
          duration: const Duration(seconds: 3),
          mainButton: TextButton(
            onPressed: () {
              // 可以在这里添加分享文件的功能
              _shareFile(filePath);
            },
            child: const Text('分享'),
          ),
        ));
      } else {
        // 其他平台尝试使用系统默认程序打开
        Process.run('open', [filePath]);
      }
    } catch (e) {
      log('打开文件失败: $e');
      getx.Get.showSnackbar(getx.GetSnackBar(
        message: '无法打开文件，请手动查找: ${filePath.split('/').last}',
        duration: const Duration(seconds: 3),
      ));
    }
  }

  /// 分享文件（iOS专用）
  static void _shareFile(String filePath) {
    // 这里可以集成share_plus插件来分享文件
    // 暂时显示文件路径
    getx.Get.dialog(
      AlertDialog(
        title: const Text('文件位置'),
        content: SelectableText(filePath),
        actions: [
          TextButton(
            onPressed: () => getx.Get.back(),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  /// 获取OpenList下载目录路径（公共方法）
  static Future<String?> getDownloadDirectoryPath() async {
    Directory? dir = await _getOpenListDownloadDirectory();
    return dir?.path;
  }

  /// 列出已下载的文件
  static Future<List<FileSystemEntity>> getDownloadedFiles() async {
    try {
      Directory? downloadDir = await _getOpenListDownloadDirectory();
      if (downloadDir != null && await downloadDir.exists()) {
        return downloadDir.listSync();
      }
    } catch (e) {
      log('获取下载文件列表失败: $e');
    }
    return [];
  }

  /// 清理下载目录
  static Future<bool> clearDownloadDirectory() async {
    try {
      Directory? downloadDir = await _getOpenListDownloadDirectory();
      if (downloadDir != null && await downloadDir.exists()) {
        await downloadDir.delete(recursive: true);
        log('已清理下载目录');
        return true;
      }
    } catch (e) {
      log('清理下载目录失败: $e');
    }
    return false;
  }

  /// 删除指定文件
  static Future<bool> deleteFile(String filename) async {
    try {
      Directory? downloadDir = await _getOpenListDownloadDirectory();
      if (downloadDir != null) {
        File file = File('${downloadDir.path}/$filename');
        if (await file.exists()) {
          await file.delete();
          log('已删除文件: $filename');
          return true;
        }
      }
    } catch (e) {
      log('删除文件失败: $e');
    }
    return false;
  }

  /// 根据文件扩展名获取MIME类型
  static String _getMimeType(String filePath) {
    String extension = filePath.split('.').last.toLowerCase();
    switch (extension) {
      case 'pdf':
        return 'application/pdf';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'mp4':
        return 'video/mp4';
      case 'mp3':
        return 'audio/mpeg';
      case 'txt':
        return 'text/plain';
      case 'zip':
        return 'application/zip';
      case 'apk':
        return 'application/vnd.android.package-archive';
      default:
        return 'application/octet-stream';
    }
  }

  /// 带进度条的下载
  static Future<bool> downloadFileWithProgress({
    required String url,
    String? filename,
  }) async {
    bool downloadSuccess = false;
    
    // 显示下载进度对话框
    getx.Get.dialog(
      getx.GetBuilder<DownloadController>(
        init: DownloadController(),
        builder: (controller) {
          return AlertDialog(
            title: const Text('下载中...'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                LinearProgressIndicator(value: controller.progress),
                const SizedBox(height: 16),
                Text('${(controller.progress * 100).toStringAsFixed(1)}%'),
                Text(controller.statusText),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  controller.cancelDownload();
                  getx.Get.back();
                },
                child: const Text('取消'),
              ),
            ],
          );
        },
      ),
      barrierDismissible: false,
    );

    final controller = getx.Get.find<DownloadController>();
    
    downloadSuccess = await downloadFile(
      url: url,
      filename: filename,
      onProgress: (received, total) {
        if (total > 0) {
          controller.updateProgress(received / total, received, total);
        }
      },
    );

    getx.Get.back(); // 关闭进度对话框
    return downloadSuccess;
  }
}

/// 下载控制器
class DownloadController extends getx.GetxController {
  double _progress = 0.0;
  String _statusText = '准备下载...';
  bool _isCancelled = false;

  double get progress => _progress;
  String get statusText => _statusText;
  bool get isCancelled => _isCancelled;

  void updateProgress(double progress, int received, int total) {
    if (_isCancelled) return;
    
    _progress = progress;
    _statusText = '${_formatBytes(received)} / ${_formatBytes(total)}';
    update();
  }

  void cancelDownload() {
    _isCancelled = true;
    _statusText = '下载已取消';
    update();
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)}GB';
  }
}