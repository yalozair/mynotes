package com.alozair.my_nots;

import android.app.Service;
import android.content.Intent;
import android.graphics.PixelFormat;
import android.os.Build;
import android.os.IBinder;
import android.view.Gravity;
import android.view.LayoutInflater;
import android.view.MotionEvent;
import android.view.View;
import android.view.WindowManager;
import android.widget.Button;
import android.widget.EditText;
import android.widget.ImageView;
import android.widget.LinearLayout;
import android.widget.Toast;


public class FloatingNoteService extends Service {
    private WindowManager windowManager;
    private View floatingView;
    private WindowManager.LayoutParams params;

    @Override
    public IBinder onBind(Intent intent) {
        return null;
    }

    @Override
    public void onCreate() {
        super.onCreate();
        floatingView = LayoutInflater.from(this).inflate(R.layout.floating_note, null);

        int layoutType;
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            layoutType = WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY;
        } else {
            layoutType = WindowManager.LayoutParams.TYPE_PHONE;
        }

        params = new WindowManager.LayoutParams(
                WindowManager.LayoutParams.WRAP_CONTENT,
                WindowManager.LayoutParams.WRAP_CONTENT,
                layoutType,
                WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE,
                PixelFormat.TRANSLUCENT);

        params.gravity = Gravity.TOP | Gravity.START;
        params.x = 0;
        params.y = 100;

        windowManager = (WindowManager) getSystemService(WINDOW_SERVICE);
        windowManager.addView(floatingView, params);

        ImageView floatingIcon = floatingView.findViewById(R.id.floating_icon);
        LinearLayout expandedView = floatingView.findViewById(R.id.expanded_view);
        EditText editText = floatingView.findViewById(R.id.floating_edit_text);
        Button saveButton = floatingView.findViewById(R.id.floating_save_button);

        floatingIcon.setOnClickListener(v -> {
            if (expandedView.getVisibility() == View.VISIBLE) {
                expandedView.setVisibility(View.GONE);
                params.flags |= WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE;
            } else {
                expandedView.setVisibility(View.VISIBLE);
                params.flags &= ~WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE;
            }
            windowManager.updateViewLayout(floatingView, params);
        });

        saveButton.setOnClickListener(v -> {
            String noteText = editText.getText().toString().trim();
            if (!noteText.isEmpty()) {
                saveNote(noteText);
                editText.setText("");
                expandedView.setVisibility(View.GONE);
                params.flags |= WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE;
                windowManager.updateViewLayout(floatingView, params);
            }
        });

        floatingView.findViewById(R.id.floating_icon).setOnTouchListener(new View.OnTouchListener() {
            private int initialX;
            private int initialY;
            private float initialTouchX;
            private float initialTouchY;

            @Override
            public boolean onTouch(View v, MotionEvent event) {
                switch (event.getAction()) {
                    case MotionEvent.ACTION_DOWN:
                        initialX = params.x;
                        initialY = params.y;
                        initialTouchX = event.getRawX();
                        initialTouchY = event.getRawY();
                        return false; // Allow click listener to work
                    case MotionEvent.ACTION_MOVE:
                        params.x = initialX + (int) (event.getRawX() - initialTouchX);
                        params.y = initialY + (int) (event.getRawY() - initialTouchY);
                        windowManager.updateViewLayout(floatingView, params);
                        return true;
                }
                return false;
            }
        });
    }

    private void saveNote(String content) {
        new Thread(() -> {
            String title = "ملاحظة سريعة " + System.currentTimeMillis();
            boolean saved = FlutterNotesStore.insertQuickNote(this, title, content);
            new android.os.Handler(getMainLooper()).post(() ->
                    Toast.makeText(
                            this,
                            saved ? "تم حفظ الملاحظة السريعة" : "تعذر حفظ الملاحظة",
                            Toast.LENGTH_SHORT
                    ).show()
            );
        }).start();
    }

    @Override
    public void onDestroy() {
        super.onDestroy();
        if (floatingView != null) windowManager.removeView(floatingView);
    }
}
