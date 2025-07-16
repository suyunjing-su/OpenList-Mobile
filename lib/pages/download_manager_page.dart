import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:open_filex/open_filex.dart';
import '../utils/download_manager.dart';

/// 下载文件管理页面
class DownloadManagerPage extends StatefulWidget {
  const DownloadManagerPage({Key? key}) : super(key: key);

  @override
  State<DownloadManagerPage> createState() => _DownloadManagerPageState();
}

class _DownloadManagerPageState extends State<DownloadManagerPage> {
  List<FileSystemEntity> _downloadedFiles = [];
  bool _isLoading = true;
  String? _downloadPath;

  @override
  void initState() {
    super.initState();
    _loadDownloadedFiles();
  }

  Future<void> _loadDownloadedFiles() async {
    setState(() {
      _isLoading = true;
    });

    try {
      _downloadedFiles = await DownloadManager.getDownloadedFiles();
      _downloadPath = await DownloadManager.getDownloadDirectoryPath();
    } catch (e) {
      print('加载下载文件失败: $e');
    }

    setState(() {
      _isLoading = false;
    });
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)}GB';
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')} '
           '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  IconData _getFileIcon(String filename) {
    String extension = filename.split('.').last.toLowerCase();
    switch (extension) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
        return Icons.image;
      case 'mp4':
      case 'avi':
      case 'mkv':
        return Icons.video_file;
      case 'mp3':
      case 'wav':
        return Icons.audio_file;
      case 'zip':
      case 'rar':
      case '7z':
        return Icons.archive;
      case 'doc':
      case 'docx':
        return Icons.description;
      case 'xls':
      case 'xlsx':
        return Icons.table_chart;
      case 'apk':
        return Icons.android;
      default:
        return Icons.insert_drive_file;
    }
  }

  void _showFileOptions(FileSystemEntity file) {
    String filename = file.path.split('/').last;
    
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              filename,
              style: Theme.of(context).textTheme.titleMedium,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.open_in_new),
              title: const Text('打开文件'),
              onTap: () async {
                Navigator.pop(context);
                await _openFile(file.path);
              },
            ),
            ListTile(
              leading: const Icon(Icons.share),
              title: const Text('分享文件'),
              onTap: () {
                Navigator.pop(context);
                // 这里可以添加分享功能
                Get.showSnackbar(const GetSnackBar(
                  message: '分享功能待实现',
                  duration: Duration(seconds: 2),
                ));
              },
            ),
            ListTile(
              leading: const Icon(Icons.info),
              title: const Text('文件信息'),
              onTap: () {
                Navigator.pop(context);
                _showFileInfo(file);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('删除文件', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                _confirmDeleteFile(filename);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showFileInfo(FileSystemEntity file) {
    String filename = file.path.split('/').last;
    FileStat stat = file.statSync();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('文件信息'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('文件名: $filename'),
            const SizedBox(height: 8),
            Text('大小: ${_formatFileSize(stat.size)}'),
            const SizedBox(height: 8),
            Text('修改时间: ${_formatDateTime(stat.modified)}'),
            const SizedBox(height: 8),
            Text('路径: ${file.path}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteFile(String filename) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除文件 "$filename" 吗？此操作不可撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              bool success = await DownloadManager.deleteFile(filename);
              if (success) {
                Get.showSnackbar(const GetSnackBar(
                  message: '文件已删除',
                  duration: Duration(seconds: 2),
                ));
                _loadDownloadedFiles(); // 刷新列表
              } else {
                Get.showSnackbar(const GetSnackBar(
                  message: '删除失败',
                  duration: Duration(seconds: 2),
                ));
              }
            },
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _confirmClearAll() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认清空'),
        content: const Text('确定要清空所有下载文件吗？此操作不可撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              bool success = await DownloadManager.clearDownloadDirectory();
              if (success) {
                Get.showSnackbar(const GetSnackBar(
                  message: '已清空下载目录',
                  duration: Duration(seconds: 2),
                ));
                _loadDownloadedFiles(); // 刷新列表
              } else {
                Get.showSnackbar(const GetSnackBar(
                  message: '清空失败',
                  duration: Duration(seconds: 2),
                ));
              }
            },
            child: const Text('清空', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  /// 打开文件
  Future<void> _openFile(String filePath) async {
    try {
      final result = await OpenFilex.open(filePath);
      
      switch (result.type) {
        case ResultType.done:
          // 文件成功打开，不需要额外提示
          break;
        case ResultType.noAppToOpen:
          Get.showSnackbar(GetSnackBar(
            message: '没有找到可以打开此文件的应用',
            duration: const Duration(seconds: 3),
            mainButton: TextButton(
              onPressed: () {
                _showFileLocation(filePath);
              },
              child: const Text('查看位置'),
            ),
          ));
          break;
        case ResultType.fileNotFound:
          Get.showSnackbar(const GetSnackBar(
            message: '文件不存在或已被删除',
            duration: Duration(seconds: 3),
          ));
          break;
        case ResultType.permissionDenied:
          Get.showSnackbar(const GetSnackBar(
            message: '没有权限打开此文件',
            duration: Duration(seconds: 3),
          ));
          break;
        case ResultType.error:
        default:
          Get.showSnackbar(GetSnackBar(
            message: '打开文件失败: ${result.message}',
            duration: const Duration(seconds: 3),
            mainButton: TextButton(
              onPressed: () {
                _showFileLocation(filePath);
              },
              child: const Text('查看位置'),
            ),
          ));
          break;
      }
    } catch (e) {
      Get.showSnackbar(GetSnackBar(
        message: '打开文件失败: ${e.toString()}',
        duration: const Duration(seconds: 3),
        mainButton: TextButton(
          onPressed: () {
            _showFileLocation(filePath);
          },
          child: const Text('查看位置'),
        ),
      ));
    }
  }

  /// 显示文件位置信息
  void _showFileLocation(String filePath) {
    Get.dialog(
      AlertDialog(
        title: const Text('文件位置'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('文件已保存到:'),
            const SizedBox(height: 8),
            SelectableText(
              filePath,
              style: const TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 16),
            const Text(
              '您可以使用文件管理器找到此文件，或者尝试安装相应的应用来打开它。',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('下载管理'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadDownloadedFiles,
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'clear_all':
                  _confirmClearAll();
                  break;
                case 'open_folder':
                  if (_downloadPath != null) {
                    Get.dialog(
                      AlertDialog(
                        title: const Text('下载目录'),
                        content: SelectableText(_downloadPath!),
                        actions: [
                          TextButton(
                            onPressed: () => Get.back(),
                            child: const Text('确定'),
                          ),
                        ],
                      ),
                    );
                  }
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'open_folder',
                child: Row(
                  children: [
                    Icon(Icons.folder_open),
                    SizedBox(width: 8),
                    Text('打开目录'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'clear_all',
                child: Row(
                  children: [
                    Icon(Icons.clear_all, color: Colors.red),
                    SizedBox(width: 8),
                    Text('清空所有', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _downloadedFiles.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.download_done,
                        size: 64,
                        color: Colors.grey,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        '暂无下载文件',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '下载的文件将显示在这里',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadDownloadedFiles,
                  child: ListView.builder(
                    itemCount: _downloadedFiles.length,
                    itemBuilder: (context, index) {
                      FileSystemEntity file = _downloadedFiles[index];
                      String filename = file.path.split('/').last;
                      FileStat stat = file.statSync();

                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        child: ListTile(
                          leading: Icon(
                            _getFileIcon(filename),
                            size: 32,
                            color: Theme.of(context).primaryColor,
                          ),
                          title: Text(
                            filename,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('大小: ${_formatFileSize(stat.size)}'),
                              Text('时间: ${_formatDateTime(stat.modified)}'),
                            ],
                          ),
                          trailing: const Icon(Icons.more_vert),
                          onTap: () => _showFileOptions(file),
                        ),
                      );
                    },
                  ),
                ),
      floatingActionButton: _downloadedFiles.isNotEmpty
          ? FloatingActionButton(
              onPressed: () {
                Get.dialog(
                  AlertDialog(
                    title: const Text('下载目录'),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('文件保存在:'),
                        const SizedBox(height: 8),
                        SelectableText(
                          _downloadPath ?? '未知',
                          style: const TextStyle(fontFamily: 'monospace'),
                        ),
                        const SizedBox(height: 16),
                        Text('共 ${_downloadedFiles.length} 个文件'),
                      ],
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Get.back(),
                        child: const Text('确定'),
                      ),
                    ],
                  ),
                );
              },
              child: const Icon(Icons.info),
            )
          : null,
    );
  }
}