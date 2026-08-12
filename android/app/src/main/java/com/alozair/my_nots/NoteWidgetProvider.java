package com.alozair.my_nots;

import android.app.PendingIntent;
import android.appwidget.AppWidgetManager;
import android.appwidget.AppWidgetProvider;
import android.content.Context;
import android.content.Intent;
import android.widget.RemoteViews;

public class NoteWidgetProvider extends AppWidgetProvider {

    @Override
    public void onUpdate(Context context, AppWidgetManager appWidgetManager, int[] appWidgetIds) {
        for (int appWidgetId : appWidgetIds) {
            updateAppWidget(context, appWidgetManager, appWidgetId);
        }
    }

    static void updateAppWidget(Context context, AppWidgetManager appWidgetManager, int appWidgetId) {
        new Thread(() -> {
            FlutterNotesStore.NotePreview note = FlutterNotesStore.getLatestNote(context);

            RemoteViews views = new RemoteViews(context.getPackageName(), R.layout.widget_layout);

            if (note != null) {
                views.setTextViewText(R.id.widget_title, note.title);
                views.setTextViewText(R.id.widget_content, note.content);
            } else {
                views.setTextViewText(R.id.widget_title, "ملاحظاتي الذكية");
                views.setTextViewText(R.id.widget_content, "لا توجد ملاحظات بعد");
            }

            Intent intent = new Intent(context, MainActivity.class);
            intent.setAction(MainActivity.ACTION_NEW_NOTE);
            PendingIntent pendingIntent = PendingIntent.getActivity(context, 0, intent,
                    PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE);
            views.setOnClickPendingIntent(R.id.widget_title, pendingIntent);
            views.setOnClickPendingIntent(R.id.widget_content, pendingIntent);
            views.setOnClickPendingIntent(R.id.widget_add, pendingIntent);

            appWidgetManager.updateAppWidget(appWidgetId, views);
        }).start();
    }
}
