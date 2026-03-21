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

        for (row in 0..1) {
            for (col in 0..1) {
                val zone = zones[row][col]
                val color = if (zone.isTapped) Color.parseColor("#00BCD4") else Color.parseColor("#444455")
                zonePaint.color = color
                canvas.drawRect(zone.rect, zonePaint)

                // Draw border
                zonePaint.style = Paint.Style.STROKE
                zonePaint.color = Color.WHITE
                zonePaint.strokeWidth = 2f
                canvas.drawRect(zone.rect, zonePaint)
                zonePaint.style = Paint.Style.FILL

                // Draw zone number
                val textX = (zone.rect.left + zone.rect.right) / 2f
                val textY = (zone.rect.top + zone.rect.bottom) / 2f - 20f
                textPaint.color = Color.WHITE
                canvas.drawText("Zone ${row * 2 + col + 1}", textX, textY, textPaint)
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

                                if (tapSequence.size >= 4) {
                                    val code = tapSequence.joinToString("")
                                    Log.d(TAG, "Knock code completed! Sequence: ${tapSequence.map { it }.joinToString(",")}")
                                    Log.d(TAG, "Generated code: '$code' (length=${code.length}, bytes=${code.toByteArray().joinToString(",")})")
                                    onKnockCodeCompleted?.invoke(code)
                                    reset()
                                }
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
