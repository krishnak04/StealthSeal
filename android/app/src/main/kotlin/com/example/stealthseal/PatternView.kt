package com.example.stealthseal

import android.content.Context
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.util.AttributeSet
import android.util.Log
import android.view.MotionEvent
import android.view.View
import kotlin.math.sqrt

/**
 * Custom view for pattern lock (3x3 grid) with drag-to-connect functionality.
 */
class PatternView @JvmOverloads constructor(
    context: Context,
    attrs: AttributeSet? = null,
    defStyleAttr: Int = 0
) : View(context, attrs, defStyleAttr) {

    companion object {
        private const val TAG = "PatternView"
    }

    private val dots = Array(3) { row -> Array(3) { col -> Dot(row, col) } }
    private val connectedDots = mutableListOf<Dot>()
    private var lastX = 0f
    private var lastY = 0f

    var onPatternCompleted: ((String) -> Unit)? = null
    var onTapUpdate: ((String) -> Unit)? = null

    private val paint = Paint(Paint.ANTI_ALIAS_FLAG)
    private val linePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = Color.parseColor("#00BCD4")
        strokeWidth = 4f
        strokeCap = Paint.Cap.ROUND
        style = Paint.Style.STROKE
    }

    inner class Dot(val row: Int, val col: Int) {
        val index = row * 3 + col  // Convert to 0-8 index
        var x = 0f
        var y = 0f
        var radius = 30f
        var isConnected = false
    }

    override fun onSizeChanged(w: Int, h: Int, oldw: Int, oldh: Int) {
        super.onSizeChanged(w, h, oldw, oldh)
        val spacing = w / 3
        val dotRadius = spacing / 8f
        for (row in 0..2) {
            for (col in 0..2) {
                dots[row][col].apply {
                    x = col * spacing + spacing / 2f
                    y = row * spacing + spacing / 2f
                    radius = dotRadius
                }
            }
        }
    }

    override fun onDraw(canvas: Canvas) {
        super.onDraw(canvas)

        // Draw lines connecting dots
        if (connectedDots.size > 1) {
            for (i in 0 until connectedDots.size - 1) {
                val from = connectedDots[i]
                val to = connectedDots[i + 1]
                canvas.drawLine(from.x, from.y, to.x, to.y, linePaint)
            }
            // Draw line from last dot to current touch
            val lastDot = connectedDots.last()
            canvas.drawLine(lastDot.x, lastDot.y, lastX, lastY, linePaint)
        }

        // Draw dots
        for (row in 0..2) {
            for (col in 0..2) {
                val dot = dots[row][col]
                val color = if (dot.isConnected) Color.parseColor("#00BCD4") else Color.parseColor("#CCCCCC")
                paint.color = color
                canvas.drawCircle(dot.x, dot.y, dot.radius, paint)

                // Draw border
                paint.style = Paint.Style.STROKE
                paint.color = if (dot.isConnected) Color.parseColor("#0099CC") else Color.parseColor("#999999")
                paint.strokeWidth = 2f
                canvas.drawCircle(dot.x, dot.y, dot.radius, paint)
                paint.style = Paint.Style.FILL
            }
        }
    }

    override fun onTouchEvent(event: MotionEvent): Boolean {
        val x = event.x
        val y = event.y

        when (event.action) {
            MotionEvent.ACTION_DOWN -> {
                connectedDots.clear()
                for (row in 0..2) {
                    for (col in 0..2) {
                        dots[row][col].isConnected = false
                    }
                }
                lastX = x
                lastY = y
                checkAndAddDot(x, y)
                invalidate()
                return true
            }
            MotionEvent.ACTION_MOVE -> {
                lastX = x
                lastY = y
                checkAndAddDot(x, y)
                invalidate()
                onTapUpdate?.invoke(connectedDots.map { it.index.toString() }.joinToString(""))
                return true
            }
            MotionEvent.ACTION_UP -> {
                if (connectedDots.size >= 4) {
                    val pattern = connectedDots.map { it.index.toString() }.joinToString("")
                    Log.d(TAG, "Pattern completed! Dots connected: ${connectedDots.map { "(${it.row},${it.col})=${it.index}" }.joinToString(", ")}")
                    Log.d(TAG, "Generated pattern: '$pattern' (length=${pattern.length}, bytes=${pattern.toByteArray().joinToString(",")})")
                    onPatternCompleted?.invoke(pattern)
                } else {
                    Log.d(TAG, "Pattern too short (${connectedDots.size} dots). Need at least 4.")
                }
                return true
            }
        }
        return false
    }

    private fun checkAndAddDot(x: Float, y: Float) {
        outerLoop@ for (row in 0..2) {
            for (col in 0..2) {
                val dot = dots[row][col]
                if (!dot.isConnected) {
                    val dist = sqrt((dot.x - x) * (dot.x - x) + (dot.y - y) * (dot.y - y))
                    if (dist < dot.radius * 1.5f) {
                        dot.isConnected = true
                        connectedDots.add(dot)
                        Log.d(TAG, "Dot connected: row=$row, col=$col, index=${dot.index}, total=${connectedDots.size}")
                        break@outerLoop
                    }
                }
            }
        }
    }

    fun reset() {
        connectedDots.clear()
        for (row in 0..2) {
            for (col in 0..2) {
                dots[row][col].isConnected = false
            }
        }
        invalidate()
    }
}
