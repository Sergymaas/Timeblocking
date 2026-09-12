package com.example.timeblocking

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == Intent.ACTION_BOOT_COMPLETED) {
            // Lanza la app en segundo plano para reprogramar notificaciones
            val serviceIntent = Intent(context, MainActivity::class.java)
            serviceIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            serviceIntent.putExtra("reprogramar_notificaciones", true)
            context.startActivity(serviceIntent)
        }
    }
}