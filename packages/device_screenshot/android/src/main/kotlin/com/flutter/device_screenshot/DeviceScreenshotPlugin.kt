package com.flutter.device_screenshot

import android.app.Activity
import android.app.ActivityManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.media.projection.MediaProjectionManager
import android.os.Build
import android.util.Log
import androidx.core.content.ContextCompat
import com.flutter.device_screenshot.src.MediaProjectionService
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.common.PluginRegistry

class DeviceScreenshotPlugin : FlutterPlugin, MethodCallHandler, ActivityAware, PluginRegistry.ActivityResultListener {
    private var context: Context? = null
    private lateinit var channel: MethodChannel
    private var activity: Activity? = null
    private val requestCodeForegroundService = 145758
    private lateinit var mediaProjectionManager: MediaProjectionManager
    private var activityBinding: ActivityPluginBinding? = null
    private var pendingResult: Result? = null
    
    private val screenshotResultReceiver = object : BroadcastReceiver() {
        override fun onReceive(ctx: Context?, intent: Intent?) {
            val path = intent?.getStringExtra("path")
            val error = intent?.getStringExtra("error")
            
            Log.d("DeviceScreenshotPlugin", "Screenshot result received: path=$path, error=$error")
            
            pendingResult?.let { result ->
                if (path != null) {
                    result.success(path)
                } else {
                    result.error("SCREENSHOT_ERROR", error ?: "Unknown error", null)
                }
                pendingResult = null
            }
        }
    }

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "device_screenshot")
        channel.setMethodCallHandler(this)
        context = flutterPluginBinding.applicationContext
        mediaProjectionManager = context?.getSystemService(Context.MEDIA_PROJECTION_SERVICE) as MediaProjectionManager
        
        // Register receiver for screenshot results
        val filter = IntentFilter(MediaProjectionService.ACTION_SCREENSHOT_RESULT)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            context?.registerReceiver(screenshotResultReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            context?.registerReceiver(screenshotResultReceiver, filter)
        }
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "bringAppToForeground" -> {
                try {
                    val intent = context?.packageManager?.getLaunchIntentForPackage(context?.packageName ?: "")
                    intent?.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_REORDER_TO_FRONT)
                    context?.startActivity(intent)
                    result.success(true)
                } catch (e: Exception) {
                    Log.e("DeviceScreenshotPlugin", "Error bringing app to foreground", e)
                    result.success(false)
                }
            }
            "checkMediaProjectionService" -> {
                val isRunning = isServiceRunning(context!!, MediaProjectionService::class.java)
                val hasProjection = MediaProjectionService.mediaProjection != null
                Log.d("DeviceScreenshotPlugin", "Service running: $isRunning, has projection: $hasProjection")
                result.success(isRunning && hasProjection)
            }
            "stopMediaProjectionService" -> {
                val stopIntent = Intent(context, MediaProjectionService::class.java)
                stopIntent.action = MediaProjectionService.ACTION_STOP_SERVICE
                context?.startService(stopIntent)
                result.success(true)
            }
            "requestMediaProjection" -> {
                requestMediaProjection()
                result.success(true)
            }
            "takeScreenshot" -> {
                pendingResult = result
                // Send broadcast to the service to capture screenshot
                val captureIntent = Intent(MediaProjectionService.ACTION_CAPTURE_SCREENSHOT)
                captureIntent.setPackage(context?.packageName)
                context?.sendBroadcast(captureIntent)
            }
            else -> {
                result.notImplemented()
            }
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        try {
            context?.unregisterReceiver(screenshotResultReceiver)
        } catch (e: Exception) {
            Log.e("DeviceScreenshotPlugin", "Error unregistering receiver", e)
        }
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activityBinding = binding
        activityBinding?.addActivityResultListener(this)
        this.activity = binding.activity
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activityBinding?.removeActivityResultListener(this)
        activityBinding = null
        this.activity = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activityBinding = binding
        activityBinding?.addActivityResultListener(this)
        this.activity = binding.activity
    }

    override fun onDetachedFromActivity() {
        activityBinding?.removeActivityResultListener(this)
        activityBinding = null
        this.activity = null
    }

    private fun requestMediaProjection() {
        // On Android 14+ (API 34+), we must request permission FIRST, then start service
        // The foreground service can only be started AFTER user grants permission
        activityBinding?.activity?.startActivityForResult(
            mediaProjectionManager.createScreenCaptureIntent(),
            requestCodeForegroundService
        )
    }

    private fun isServiceRunning(context: Context, serviceClass: Class<*>): Boolean {
        val manager = context.getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager?
        @Suppress("DEPRECATION")
        for (service in manager?.getRunningServices(Int.MAX_VALUE) ?: emptyList()) {
            if (serviceClass.name == service.service.className) {
                return true
            }
        }
        return false
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        Log.d("DeviceScreenshotPlugin", "onActivityResult: requestCode=$requestCode, resultCode=$resultCode")
        
        when (requestCode) {
            requestCodeForegroundService -> {
                if (resultCode == Activity.RESULT_OK && data != null) {
                    Log.d("DeviceScreenshotPlugin", "MediaProjection permission granted, starting service with projection")
                    
                    // NOW start the foreground service with the projection data
                    // This is the correct order for Android 14+ (API 34+)
                    val serviceIntent = Intent(activity, MediaProjectionService::class.java)
                    serviceIntent.action = MediaProjectionService.ACTION_INIT_PROJECTION
                    serviceIntent.putExtra("resultCode", resultCode)
                    serviceIntent.putExtra("resultData", data)
                    
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        ContextCompat.startForegroundService(activity!!, serviceIntent)
                    } else {
                        activity?.startService(serviceIntent)
                    }
                } else {
                    Log.d("DeviceScreenshotPlugin", "MediaProjection permission denied")
                }
                return true
            }
        }
        return false
    }
}
