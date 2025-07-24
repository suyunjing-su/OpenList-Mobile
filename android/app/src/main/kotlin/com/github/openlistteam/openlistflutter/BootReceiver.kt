package com.openlist.mobile

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import com.openlist.mobile.config.AppConfig

class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == Intent.ACTION_BOOT_COMPLETED && AppConfig.isStartAtBootEnabled) {
            context.startService(Intent(context, OpenListService::class.java))
        }
    }
}
