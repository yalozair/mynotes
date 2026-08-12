package com.alozair.my_nots;

import android.content.Context;
import android.graphics.Canvas;
import android.graphics.Color;
import android.graphics.Paint;
import android.graphics.Rect;
import android.util.AttributeSet;
import androidx.appcompat.widget.AppCompatEditText;

public class LinedEditText extends AppCompatEditText {
    private Rect mRect;
    private Paint mPaint;
    private Paint mLineNumberPaint;
    private boolean mShowLines = true;
    private boolean mShowLineNumbers = true;

    public LinedEditText(Context context, AttributeSet attrs) {
        super(context, attrs);
        init();
    }

    private void init() {
        mRect = new Rect();
        
        // Paint for the ruled lines
        mPaint = new Paint();
        mPaint.setStyle(Paint.Style.STROKE);
        mPaint.setColor(0x40000000); // Very light black/gray for lines
        mPaint.setStrokeWidth(1);

        // Paint for the line numbers
        mLineNumberPaint = new Paint();
        mLineNumberPaint.setColor(Color.GRAY);
        mLineNumberPaint.setTextSize(24);
        mLineNumberPaint.setAntiAlias(true);
        mLineNumberPaint.setTextAlign(Paint.Align.RIGHT);

        // Add padding to the left to make room for line numbers
        updatePadding();
    }

    private void updatePadding() {
        int leftPadding = mShowLineNumbers ? 70 : 20;
        setPadding(leftPadding, getPaddingTop(), getPaddingRight(), getPaddingBottom());
    }

    public void setShowLines(boolean show) {
        this.mShowLines = show;
        invalidate();
    }

    public void setShowLineNumbers(boolean show) {
        this.mShowLineNumbers = show;
        updatePadding();
        invalidate();
    }

    @Override
    protected void onDraw(Canvas canvas) {
        int count = getLineCount();
        int layoutCount = getLayout() != null ? getLayout().getLineCount() : count;
        
        Rect r = mRect;
        Paint paint = mPaint;

        // Determine the height of one line
        int lineHeight = getLineHeight();
        int basePadding = getExtendedPaddingTop();

        for (int i = 0; i < layoutCount; i++) {
            int baseline = getLineBounds(i, r);
            
            // 1. Draw horizontal lines if enabled
            if (mShowLines) {
                canvas.drawLine(r.left, baseline + 5, r.right, baseline + 5, paint);
            }

            // 2. Draw line numbers if enabled (only for real new lines, not wrapped ones)
            if (mShowLineNumbers) {
                // Check if this is the start of a paragraph/actual line
                // For simplicity in this version, we draw numbers for all layout lines
                // but we can refine this later if needed.
                String lineNumber = String.valueOf(i + 1);
                canvas.drawText(lineNumber, 55, baseline, mLineNumberPaint);
            }
        }

        // Draw extra lines to fill the screen even if there's no text
        int height = getHeight();
        int currentHeight = (layoutCount * lineHeight) + basePadding;
        while (currentHeight < height && mShowLines) {
            canvas.drawLine(0, currentHeight, getWidth(), currentHeight, paint);
            currentHeight += lineHeight;
        }

        super.onDraw(canvas);
    }
}
