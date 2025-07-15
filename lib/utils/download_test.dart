import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'download_manager.dart';
import '../pages/download_manager_page.dart';

/// 下载功能测试页面
class DownloadTestPage extends StatelessWidget {
  const DownloadTestPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('下载功能测试'),
      ),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '测试直接下载功能',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                // 测试下载一个小文件
                await DownloadManager.downloadFileWithProgress(
                  url: 'https://httpbin.org/json',
                  filename: 'test.json',
                );
              },
              child: Text('测试下载JSON文件'),
            ),
            SizedBox(height: 10),
            ElevatedButton(
              onPressed: () async {
                // 测试下载图片
                await DownloadManager.downloadFileWithProgress(
                  url: 'https://httpbin.org/image/png',
                  filename: 'test_image.png',
                );
              },
              child: Text('测试下载PNG图片'),
            ),
            SizedBox(height: 10),
            ElevatedButton(
              onPressed: () async {
                // 测试下载较大文件
                await DownloadManager.downloadFileWithProgress(
                  url: 'https://httpbin.org/drip?duration=5&numbytes=1024000',
                  filename: 'large_test.bin',
                );
              },
              child: Text('测试下载大文件(1MB)'),
            ),
            SizedBox(height: 10),
            ElevatedButton(
              onPressed: () {
                // 打开下载管理页面
                Get.to(() => DownloadManagerPage());
              },
              child: Text('查看下载文件'),
            ),
            SizedBox(height: 10),
            ElevatedButton(
              onPressed: () async {
                // 显示下载目录路径
                String? path = await DownloadManager.getDownloadDirectoryPath();
                Get.dialog(
                  AlertDialog(
                    title: Text('下载目录'),
                    content: SelectableText(path ?? '获取失败'),
                    actions: [
                      TextButton(
                        onPressed: () => Get.back(),
                        child: Text('确定'),
                      ),
                    ],
                  ),
                );
              },
              child: Text('查看下载目录'),
            ),
            SizedBox(height: 20),
            Text(
              '说明：',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Text(
              '• 文件将下载到系统下载目录\n'
              '• 下载过程���会显示进度对话框\n'
              '• 下载完成后可以选择打开文件\n'
              '• 如果文件名重复会自动添加序号',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

/// 在主应用中添加测试入口的辅助方法
class DownloadTestHelper {
  static void showTestDialog(BuildContext context) {
    Get.dialog(
      AlertDialog(
        title: Text('下载功能测试'),
        content: Text('是否要打开下载测试页面？'),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Get.back();
              Get.to(() => DownloadTestPage());
            },
            child: Text('确定'),
          ),
        ],
      ),
    );
  }
}