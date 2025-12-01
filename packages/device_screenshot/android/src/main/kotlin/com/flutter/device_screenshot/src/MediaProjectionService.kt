package com.flutter.device_screenshot.src

import android.app.Activity
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.ServiceInfo
import android.graphics.Bitmap
import android.graphics.PixelFormat
import android.hardware.display.DisplayManager
import android.hardware.display.VirtualDisplay
import android.media.Image
import android.media.ImageReader
import android.media.projection.MediaProjection
import android.media.projection.MediaProjectionManager
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.util.DisplayMetrics
import android.util.Log
import android.view.WindowManager
import androidx.annotation.RequiresApi
import androidx.core.app.NotificationCompat
import java.io.File
import java.io.FileOutputStream

class MediaProjectionService : Service() {
    companion object {
        const val NOTIFICATION_CHANNEL_ID = "MediaProjectionForegroundServiceChannel"
        const val ACTION_STOP_SERVICE = "MediaProjectionForegroundServiceStop"
        const val ACTION_CAPTURE_SCREENSHOT = "com.flutter.device_screenshot.CAPTURE_SCREENSHOT"
        const val ACTION_SCREENSHOT_RESULT = "com.flutter.device_screenshot.SCREENSHOT_RESULT"
        const val ACTION_INIT_PROJECTION = "com.flutter.device_screenshot.INIT_PROJECTION"
        const val NOTIFICATION_ID = 1
        
        private var instance: MediaProjectionService? = null
        
        fun getInstance(): MediaProjectionService? = instance
        
        var mediaProjection: MediaProjection? = null
            private set
        
        var resultCode: Int = Activity.RESULT_CANCELED
        var resultData: Intent? = null
        
        // File-based communication directory name
        const val COMM_DIR = "ghost_comm"
        const val REQUEST_FILE = "capture_request"
        const val RESULT_FILE = "capture_result"
    }
    
    private var virtualDisplay: VirtualDisplay? = null
    private var imageReader: ImageReader? = null
    private var screenWidth: Int = 0
    private var screenHeight: Int = 0
    private var screenDensity: Int = 0
    private val handler = Handler(Looper.getMainLooper())
    private var commDir: File? = null
    private var pollingRunnable: Runnable? = null
    private var isPolling = false
    
    private val captureReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            Log.d("MediaProjectionService", "Received capture request via broadcast")
            captureScreenshot(false)
        }
    }

    override fun onBind(intent: Intent?): IBinder? {
        return null
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Log.d("MediaProjectionService", "onStartCommand action: ${intent?.action}")
        
        return when (intent?.action) {
            ACTION_STOP_SERVICE -> {
                cleanup()
                stopSelf()
                START_NOT_STICKY
            }
            ACTION_INIT_PROJECTION -> {
                // Check if already initialized
                if (mediaProjection != null) {
                    Log.d("MediaProjectionService", "MediaProjection already initialized, skipping")
                    return START_STICKY
                }
                
                // On Android 14+ (API 34+), we must call startForeground IMMEDIATELY
                // when starting the service with MediaProjection permission
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    startForegroundWithNotification()
                }
                
                resultCode = intent.getIntExtra("resultCode", Activity.RESULT_CANCELED)
                resultData = intent.getParcelableExtra("resultData")
                initMediaProjection()
                START_STICKY
            }
            else -> {
                START_STICKY
            }
        }
    }
    
    @RequiresApi(Build.VERSION_CODES.O)
    private fun startForegroundWithNotification() {
        createNotificationChannel()

        val builder = NotificationCompat.Builder(this, NOTIFICATION_CHANNEL_ID)
            .setContentTitle("Ghost Detector")
            .setContentText("Ready to capture screenshots")
            .setSmallIcon(android.R.drawable.ic_menu_camera)
            .setOngoing(true)

        val notification = builder.build()

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(NOTIFICATION_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PROJECTION)
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
        
        Log.d("MediaProjectionService", "Started foreground with notification")
    }
    
    private fun initMediaProjection() {
        Log.d("MediaProjectionService", "Initializing MediaProjection")
        val projectionManager = getSystemService(MEDIA_PROJECTION_SERVICE) as MediaProjectionManager
        
        resultData?.let { data ->
            // Create a copy of the intent to avoid issues with reusing
            val dataCopy = Intent(data)
            mediaProjection = projectionManager.getMediaProjection(resultCode, dataCopy)
            Log.d("MediaProjectionService", "MediaProjection created: ${mediaProjection != null}")
            
            mediaProjection?.registerCallback(object : MediaProjection.Callback() {
                override fun onStop() {
                    Log.d("MediaProjectionService", "MediaProjection stopped callback - NOT cleaning up to preserve polling")
                    // Don't cleanup here - just log it
                    // The service will continue polling and report error if capture is attempted
                    mediaProjection = null
                    virtualDisplay?.release()
                    virtualDisplay = null
                    imageReader?.close()
                    imageReader = null
                }
            }, handler)
            
            setupVirtualDisplay()
        }
    }
    
    private fun setupVirtualDisplay() {
        val windowManager = getSystemService(Context.WINDOW_SERVICE) as WindowManager
        val metrics = DisplayMetrics()
        
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            val bounds = windowManager.currentWindowMetrics.bounds
            screenWidth = bounds.width()
            screenHeight = bounds.height()
            screenDensity = resources.configuration.densityDpi
        } else {
            @Suppress("DEPRECATION")
            windowManager.defaultDisplay.getMetrics(metrics)
            screenWidth = metrics.widthPixels
            screenHeight = metrics.heightPixels
            screenDensity = metrics.densityDpi
        }
        
        Log.d("MediaProjectionService", "Screen: ${screenWidth}x${screenHeight} @ $screenDensity")
        
        imageReader = ImageReader.newInstance(screenWidth, screenHeight, PixelFormat.RGBA_8888, 2)
        
        virtualDisplay = mediaProjection?.createVirtualDisplay(
            "GhostDetectorCapture",
            screenWidth,
            screenHeight,
            screenDensity,
            DisplayManager.VIRTUAL_DISPLAY_FLAG_AUTO_MIRROR,
            imageReader?.surface,
            null,
            handler
        )
        
        Log.d("MediaProjectionService", "VirtualDisplay created: ${virtualDisplay != null}")
    }
    
    private fun captureScreenshot(fromFile: Boolean) {
        Log.d("MediaProjectionService", "Capturing screenshot, imageReader: ${imageReader != null}, fromFile: $fromFile")
        
        if (mediaProjection == null || imageReader == null) {
            Log.e("MediaProjectionService", "MediaProjection or ImageReader is null")
            if (fromFile) {
                writeResultFile(null, "MediaProjection not initialized")
            } else {
                sendScreenshotResult(null, "MediaProjection not initialized")
            }
            return
        }
        
        // Add small delay to ensure screen is rendered
        handler.postDelayed({
            try {
                val image: Image? = imageReader?.acquireLatestImage()
                
                if (image == null) {
                    Log.e("MediaProjectionService", "No image available")
                    if (fromFile) {
                        writeResultFile(null, "No image available")
                    } else {
                        sendScreenshotResult(null, "No image available")
                    }
                    return@postDelayed
                }
                
                val planes = image.planes
                val buffer = planes[0].buffer
                val pixelStride = planes[0].pixelStride
                val rowStride = planes[0].rowStride
                val rowPadding = rowStride - pixelStride * screenWidth
                
                val bitmap = Bitmap.createBitmap(
                    screenWidth + rowPadding / pixelStride,
                    screenHeight,
                    Bitmap.Config.ARGB_8888
                )
                bitmap.copyPixelsFromBuffer(buffer)
                image.close()
                
                // Crop to actual screen size
                val croppedBitmap = Bitmap.createBitmap(bitmap, 0, 0, screenWidth, screenHeight)
                if (croppedBitmap != bitmap) {
                    bitmap.recycle()
                }
                
                // Save to file
                val screenshotDir = File(getExternalFilesDir(null), "screenshots")
                if (!screenshotDir.exists()) {
                    screenshotDir.mkdirs()
                }
                
                val file = File(screenshotDir, "screenshot_${System.currentTimeMillis()}.png")
                FileOutputStream(file).use { out ->
                    croppedBitmap.compress(Bitmap.CompressFormat.PNG, 100, out)
                }
                croppedBitmap.recycle()
                
                Log.d("MediaProjectionService", "Screenshot saved to: ${file.absolutePath}")
                
                if (fromFile) {
                    writeResultFile(file.absolutePath, null)
                } else {
                    sendScreenshotResult(file.absolutePath, null)
                }
                
            } catch (e: Exception) {
                Log.e("MediaProjectionService", "Error capturing screenshot", e)
                if (fromFile) {
                    writeResultFile(null, e.message)
                } else {
                    sendScreenshotResult(null, e.message)
                }
            }
        }, 100)
    }
    
    private fun sendScreenshotResult(path: String?, error: String?) {
        val intent = Intent(ACTION_SCREENSHOT_RESULT)
        intent.setPackage(packageName)
        if (path != null) {
            intent.putExtra("path", path)
        }
        if (error != null) {
            intent.putExtra("error", error)
        }
        sendBroadcast(intent)
    }
    
    private fun setupFilePolling() {
        // Create communication directory
        commDir = File(getExternalFilesDir(null), COMM_DIR)
        Log.d("MediaProjectionService", "Setting up file polling at: ${commDir!!.absolutePath}")
        
        if (!commDir!!.exists()) {
            val created = commDir!!.mkdirs()
            Log.d("MediaProjectionService", "Created comm dir: $created")
        }
        
        // Clean any old request files
        File(commDir, REQUEST_FILE).delete()
        File(commDir, RESULT_FILE).delete()
        
        // Start polling for request file
        isPolling = true
        pollingRunnable = object : Runnable {
            override fun run() {
                if (!isPolling) return
                
                val requestFile = File(commDir, REQUEST_FILE)
                if (requestFile.exists()) {
                    Log.d("MediaProjectionService", "Request file detected via polling!")
                    requestFile.delete()
                    captureScreenshot(true)
                }
                
                // Check again in 100ms
                handler.postDelayed(this, 100)
            }
        }
        handler.post(pollingRunnable!!)
        Log.d("MediaProjectionService", "File polling started")
    }
    
    private fun stopFilePolling() {
        isPolling = false
        pollingRunnable?.let { handler.removeCallbacks(it) }
        pollingRunnable = null
        Log.d("MediaProjectionService", "File polling stopped")
    }
    
    private fun writeResultFile(path: String?, error: String?) {
        try {
            val resultFile = File(commDir, RESULT_FILE)
            if (path != null) {
                resultFile.writeText("success:$path")
            } else {
                resultFile.writeText("error:${error ?: "Unknown error"}")
            }
            Log.d("MediaProjectionService", "Result written to: ${resultFile.absolutePath}")
        } catch (e: Exception) {
            Log.e("MediaProjectionService", "Error writing result file", e)
        }
    }
    
    private fun cleanup() {
        stopFilePolling()
        virtualDisplay?.release()
        virtualDisplay = null
        imageReader?.close()
        imageReader = null
        mediaProjection?.stop()
        mediaProjection = null
    }

    @RequiresApi(Build.VERSION_CODES.O)
    override fun onCreate() {
        super.onCreate()
        instance = this
        
        // Register broadcast receiver for capture requests
        val filter = IntentFilter(ACTION_CAPTURE_SCREENSHOT)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(captureReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            registerReceiver(captureReceiver, filter)
        }
        
        // Setup file-based communication for overlay
        setupFilePolling()
        
        Log.d("MediaProjectionService", "Service created and receiver registered")
    }
    
    override fun onDestroy() {
        super.onDestroy()
        instance = null
        try {
            unregisterReceiver(captureReceiver)
        } catch (e: Exception) {
            Log.e("MediaProjectionService", "Error unregistering receiver", e)
        }
        cleanup()
        Log.d("MediaProjectionService", "Service destroyed")
    }

    fun closeNotification() {
        val stopIntent = Intent(this, MediaProjectionService::class.java)
        stopIntent.action = ACTION_STOP_SERVICE
        startService(stopIntent)
    }

    @RequiresApi(Build.VERSION_CODES.O)
    private fun createNotificationChannel() {
        val channelName = "Ghost Detector Screen Capture"
        val channelDescription = "Used for capturing screenshots in background"

        val channel = NotificationChannel(
            NOTIFICATION_CHANNEL_ID,
            channelName,
            NotificationManager.IMPORTANCE_LOW
        ).apply {
            description = channelDescription
        }

        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        notificationManager.createNotificationChannel(channel)
    }
}
