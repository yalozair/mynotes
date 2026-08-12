package com.alozair.my_nots;

import android.app.NotificationManager;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.widget.Toast;

public class NotificationActionReceiver extends BroadcastReceiver {
    @Override
    public void onReceive(Context context, Intent intent) {
        String action = intent.getAction();
        if ("ACTION_DONE".equals(action)) {
            int notificationId = intent.getIntExtra("notification_id", 0);
            NotificationManager manager = (NotificationManager) context.getSystemService(Context.NOTIFICATION_SERVICE);
            manager.cancel(notificationId);
            Toast.makeText(context, "تم تحديد المهمة كمكتملة", Toast.LENGTH_SHORT).show();
        }
    }
}
