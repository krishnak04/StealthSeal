package com.example.stealthseal

import android.content.Context
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Rect
import android.util.AttributeSet
import android.util.Log
import android.view.MotionEvent
import android.view.View

/**
 * Custom view for knock code (4-zone grid) with tap tracking.
 */
class KnockCodeView @JvmOverloads constructor(
    context: Context,
    attrs: AttributeSet? = null,
    defStyleAttr: Int = 0
) : View(context, attrs, defStyleAttr) {

    companion object {
        private const val TAG = "KnockCodeView"
    }

    private val zones = Array(2) { row -> Array(2) { col -> Zone(row, col) } }
    private val tapSequence = mutableListOf<String>()
    private val zonePaint = Paint(Paint.ANTI_ALIAS_FLAG)
    private val textPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = Color.WHITE
        textSize = 40f
        textAlign = Paint.Align.CENTER
    }

    var onKnockCodeCompleted: ((String) -> Unit)? = null
    var onTapUpdate: ((String) -> Unit)? = null
    var onTooShort: (() -> Unit)? = null
    
    fun getCurrentCode(): String = tapSequence.joinToString("")
    fun getCodeLength(): Int = tapSequence.size

    inner class Zone(val row: Int, val col: Int) {
        val rect = Rect()
        var isTapped = false
    }

    override fun onSizeChanged(w: Int, h: Int, oldw: Int, oldh: Int) {
        super.onSizeChanged(w, h, oldw, oldh)
        val zoneWidth = w / 2
        val zoneHeight = h / 2
        for (row in 0..1) {
            for (col in 0..1) {
                zones[row][col].rect.apply {
                    left = col * zoneWidth
                    top = row * zoneHeight
                    right = (col + 1) * zoneWidth
                    bottom = (row + 1) * zoneHeight
                }
            }
        }
    }

    override fun onDraw(canvas: Canvas) {
        super.onDraw(canvas)

        // Draw corner markers (like in pattern UI)
        val cornerSize = 20f
        val strokeWidth = 3f
        val cornerPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.parseColor("#CCCCCC")
            this.strokeWidth = strokeWidth
            style = Paint.Style.STROKE
        }

        // Top-left corner
        canvas.drawLine(0f, cornerSize, cornerSize, cornerSize, cornerPaint)
        canvas.drawLine(cornerSize, 0f, cornerSize, cornerSize, cornerPaint)

        // Top-right corner
        canvas.drawLine(width.toFloat() - cornerSize, cornerSize, width.toFloat(), cornerSize, cornerPaint)
        canvas.drawLine(width.toFloat() - cornerSize, 0f, width.toFloat() - cornerSize, cornerSize, cornerPaint)

        // Bottom-left corner
        canvas.drawLine(0f, height.toFloat() - cornerSize, cornerSize, height.toFloat() - cornerSize, cornerPaint)
        canvas.drawLine(cornerSize, height.toFloat() - cornerSize, cornerSize, height.toFloat(), cornerPaint)

        // Bottom-right corner
        canvas.drawLine(width.toFloat() - cornerSize, height.toFloat() - cornerSize, width.toFloat(), height.toFloat() - cornerSize, cornerPaint)
        canvas.drawLine(width.toFloat() - cornerSize, height.toFloat() - cornerSize, width.toFloat() - cornerSize, height.toFloat(), cornerPaint)

        // Draw crosshairs (center lines)
        val centerX = width / 2f
        val centerY = height / 2f
        val crossPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.parseColor("#AAAAAA")
            this.strokeWidth = 2f
            style = Paint.Style.STROKE
        }

        canvas.drawLine(centerX, 0f, centerX, height.toFloat(), crossPaint)
        canvas.drawLine(0f, centerY, width.toFloat(), centerY, crossPaint)

        // Draw zones as simple rectangles
        for (row in 0..1) {
            for (col in 0..1) {
                val zone = zones[row][col]
                val color = if (zone.isTapped) Color.parseColor("#4CAF50") else Color.parseColor("#555555")
                zonePaint.color = color
                zonePaint.style = Paint.Style.FILL
                canvas.drawRect(zone.rect, zonePaint)

                // Draw border
                zonePaint.style = Paint.Style.STROKE
                zonePaint.color = Color.parseColor("#FFFFFF")
                zonePaint.strokeWidth = 2f
                canvas.drawRect(zone.rect, zonePaint)
                zonePaint.style = Paint.Style.FILL
            }
        }
    }

    override fun onTouchEvent(event: MotionEvent): Boolean {
        val x = event.x.toInt()
        val y = event.y.toInt()

        when (event.action) {
            MotionEvent.ACTION_DOWN -> {
                for (row in 0..1) {
                    for (col in 0..1) {
                        val zone = zones[row][col]
                        if (zone.rect.contains(x, y)) {
                            if (tapSequence.size < 6) {
                                val zoneIndex = row * 2 + col
                                tapSequence.add(zoneIndex.toString())
                                zone.isTapped = true
                                
                                Log.d(TAG, "Zone tapped: row=$row, col=$col, index=$zoneIndex, total=${tapSequence.size}")
                                
                                onTapUpdate?.invoke(tapSequence.joinToString(""))
                                invalidate()
                            }
                            return true
                        }
                    }
                }
            }
        }

        return false
    }

    fun reset() {
        tapSequence.clear()
        for (row in 0..1) {
            for (col in 0..1) {
                zones[row][col].isTapped = false
            }
        }
        invalidate()
    }
}
