package com.alozair.my_nots;
import android.app.NotificationManager;

import android.app.PendingIntent;

import android.content.Context;

import android.content.ContextParams;
import android.content.Intent;
import android.widget.Toast;


import androidx.core.app.NotificationCompat;


import com.google.firebase.crashlytics.FirebaseCrashlytics;
import com.google.firebase.messaging.FirebaseMessagingService;

import com.google.firebase.messaging.RemoteMessage;


public class FcmMessagingService extends FirebaseMessagingService {

    @Override

    public void onMessageReceived(RemoteMessage remoteMessage) {
try{

        if (remoteMessage.getData().size() > 0) {

            String title = remoteMessage.getNotification().getTitle();

            String message = remoteMessage.getNotification().getBody();


            Intent i = new Intent(FcmMessagingService.this, MainActivity.class);


            i.addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP);


            PendingIntent notification = PendingIntent.getActivity(this, 0, i, PendingIntent.FLAG_IMMUTABLE);
            //PendingIntent notification = PendingIntent.getActivity(this, 0, i, PendingIntent.FLAG_ONE_SHOT );


            NotificationCompat.Builder builder = new NotificationCompat.Builder(this);


            builder.setSmallIcon(R.mipmap.ic_launcher);

            builder.setContentTitle(title);

            builder.setContentText(message);


            builder.setContentIntent(notification);

            builder.setDefaults(NotificationCompat.DEFAULT_SOUND);

            builder.setAutoCancel(true);


            NotificationManager mm = (NotificationManager) getSystemService(Context.NOTIFICATION_SERVICE);

            mm.cancel(1);

            mm.notify(1, builder.build());

        }


} catch (Exception ex) {
    Toast.makeText(this, "On Create : " + ex.getMessage(), Toast.LENGTH_LONG).show();
    FirebaseCrashlytics.getInstance().recordException(ex);
}

    }


}
