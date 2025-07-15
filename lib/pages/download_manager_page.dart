import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
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
        padding: EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              filename,
              style: Theme.of(context).textTheme.titleMedium,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: 16),
            ListTile(
              leading: Icon(Icons.open_in_new),
              title: Text('打开文件'),
              onTap: () {
                Navigator.pop(context);
                // 这里调用打开文件的方法
                if (Platform.isAndroid) {
                  Process.run('am', [
                    'start',
                    '-a', 'android.intent.action.VIEW',
                    '-d', 'file://${file.path}',
                  ]);
                } else {
                  Get.showSnackbar(GetSnackBar(
                    message: '文件位置: ${file.path}',
                    duration: Duration(seconds: 3),
                  ));
                }
              },
            ),
            ListTile(
              leading: Icon(Icons.share),
              title: Text('分享文件'),
              onTap: () {
                Navigator.pop(context);
                // 这里可以添加分享功能
                Get.showSnackbar(GetSnackBar(
                  message: '分享功能待实现',
                  duration: Duration(seconds: 2),
                ));
              },
            ),
            ListTile(
              leading: Icon(Icons.info),
              title: Text('文件信息'),
              onTap: () {
                Navigator.pop(context);
                _showFileInfo(file);
              },
            ),
            ListTile(
              leading: Icon(Icons.delete, color: Colors.red),
              title: Text('删除文件', style: TextStyle(color: Colors.red)),
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
        title: Text('文件信息'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('文件名: $filename'),
            SizedBox(height: 8),
            Text('大小: ${_formatFileSize(stat.size)}'),
            SizedBox(height: 8),
            Text('修改时间: ${_formatDateTime(stat.modified)}'),
            SizedBox(height: 8),
            Text('路径: ${file.path}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('确定'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteFile(String filename) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('确认删除'),
        content: Text('确定要删除文件 "$filename" 吗？此操作不可撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              bool success = await DownloadManager.deleteFile(filename);
              if (success) {
                Get.showSnackbar(GetSnackBar(
                  message: '文件已删除',
                  duration: Duration(seconds: 2),
                ));
                _loadDownloadedFiles(); // 刷新列表
              } else {
                Get.showSnackbar(GetSnackBar(
                  message: '删除失败',
                  duration: Duration(seconds: 2),
                ));
              }
            },
            child: Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _confirmClearAll() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('确认清空'),
        content: Text('确定要清空所有下载文件吗？此操作不可撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              bool success = await DownloadManager.clearDownloadDirectory();
              if (success) {
                Get.showSnackbar(GetSnackBar(
                  message: '已清空下载目录',
                  duration: Duration(seconds: 2),
                ));
                _loadDownloadedFiles(); // 刷新列表
              } else {
                Get.showSnackbar(GetSnackBar(
                  message: '清空失败',
                  duration: Duration(seconds: 2),
                ));
              }
            },
            child: Text('清空', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('下载管理'),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
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
                        title: Text('下载目录'),
                        content: SelectableText(_downloadPath!),
                        actions: [
                          TextButton(
                            onPressed: () => Get.back(),
                            child: Text('确定'),
                          ),
                        ],
                      ),
                    );
                  }
                  break;
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'open_folder',
                child: Row(
                  children: [
                    Icon(Icons.folder_open),
                    SizedBox(width: 8),
                    Text('打开目录'),
                  ],
                ),
              ),
              PopupMenuItem(
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
          ? Center(child: CircularProgressIndicator())
          : _downloadedFiles.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.download_done,
                        size: 64,
                        color: Colors.grey,
                      ),
                      SizedBox(height: 16),
                      Text(
                        '暂无下载文件',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Colors.grey,
                        ),
                      ),
                      SizedBox(height: 8),
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
                        margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
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
                          trailing: Icon(Icons.more_vert),
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
                    title: Text('下载目录'),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('文件保存在:'),
                        SizedBox(height: 8),
                        SelectableText(
                          _downloadPath ?? '未知',
                          style: TextStyle(fontFamily: 'monospace'),
                        ),
                        SizedBox(height: 16),
                        Text('共 ${_downloadedFiles.length} 个文件'),
                      ],
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Get.back(),
                        child: Text('确定'),
                      ),
                    ],
                  ),
                );
              },
              child: Icon(Icons.info),
            )
          : null,
    );
  }
}