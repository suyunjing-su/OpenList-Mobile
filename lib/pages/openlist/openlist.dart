import 'package:openlist_flutter/generated_api.dart';
import 'package:openlist_flutter/pages/openlist/about_dialog.dart';
import 'package:openlist_flutter/pages/openlist/pwd_edit_dialog.dart';
import 'package:openlist_flutter/pages/app_update_dialog.dart';
import 'package:openlist_flutter/pages/download_manager_page.dart';
import 'package:openlist_flutter/widgets/switch_floating_action_button.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../generated/l10n.dart';
import 'log_list_view.dart';

class OpenListScreen extends StatelessWidget {
  const OpenListScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final ui = Get.put(OpenListController());

    return Scaffold(
        appBar: AppBar(
            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
            title: Obx(() => Text("OpenList - ${ui.openlistVersion.value}")),
            actions: [
              IconButton(
                tooltip: S.of(context).desktopShortcut,
                onPressed: () async  {
                  Android().addShortcut();
                },
                icon: const Icon(Icons.add_home),
              ),
              IconButton(
                tooltip: S.current.setAdminPassword,
                onPressed: () {
                  showDialog(
                      context: context,
                      builder: (context) => PwdEditDialog(onConfirm: (pwd) {
                            Get.showSnackbar(GetSnackBar(
                                title: S.current.setAdminPassword,
                                message: pwd,
                                duration: const Duration(seconds: 1)));
                            Android().setAdminPwd(pwd);
                          }));
                },
                icon: const Icon(Icons.password),
              ),
              PopupMenuButton(
                tooltip: S.of(context).moreOptions,
                itemBuilder: (context) {
                  return [
                    PopupMenuItem(
                      value: 1,
                      onTap: () {
                        Get.to(() => const DownloadManagerPage());
                      },
                      child: const Row(
                        children: [
                          Icon(Icons.download),
                          SizedBox(width: 8),
                          Text('下载管理'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 2,
                      onTap: () async {
                        AppUpdateDialog.checkUpdateAndShowDialog(context, (b) {
                          if (!b) {
                            Get.showSnackbar(GetSnackBar(
                                message: S.of(context).currentIsLatestVersion,
                                duration: const Duration(seconds: 2)));
                          }
                        });
                      },
                      child: Text(S.of(context).checkForUpdates),
                    ),
                    PopupMenuItem(
                      value: 3,
                      onTap: () {
                        showDialog(context: context, builder: ((context){
                          return const AppAboutDialog();
                        }));
                      },
                      child: Text(S.of(context).about),
                    ),
                  ];
                },
                icon: const Icon(Icons.more_vert),
              )
            ]),
        floatingActionButton: Obx(
          () => SwitchFloatingButton(
              isSwitch: ui.isSwitch.value,
              onSwitchChange: (s) {
                ui.clearLog();
                ui.isSwitch.value = s;
                Android().startService();
              }),
        ),
        body: Obx(() => LogListView(logs: ui.logs.value)));
  }
}

class MyEventReceiver extends Event {
  Function(Log log) logCb;
  Function(bool isRunning) statusCb;

  MyEventReceiver(this.statusCb, this.logCb);

  @override
  void onServiceStatusChanged(bool isRunning) {
    statusCb(isRunning);
  }

  @override
  void onServerLog(int level, String time, String log) {
    logCb(Log(level, time, log));
  }
}

class OpenListController extends GetxController {
  final ScrollController _scrollController = ScrollController();
  var isSwitch = false.obs;
  var openlistVersion = "".obs;

  var logs = <Log>[].obs;

  void clearLog() {
    logs.clear();
  }

  void addLog(Log log) {
    logs.add(log);
    _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
  }

  @override
  void onInit() {
    Event.setup(MyEventReceiver(
        (isRunning) => isSwitch.value = isRunning, (log) => addLog(log)));
    Android().getOpenListVersion().then((value) => openlistVersion.value = value);
    Android().isRunning().then((value) => isSwitch.value = value);

    super.onInit();
  }
}
