package com.example.guess_me;

import io.flutter.embedding.android.FlutterActivity;

import android.content.Intent;
import android.content.IntentFilter;
import android.content.BroadcastReceiver;
import android.os.Build;
import android.provider.Settings;
import android.app.ActivityManager;
import android.content.Context;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.EventChannel;
import android.content.pm.PackageManager;
import androidx.core.app.ActivityCompat;
import androidx.core.content.ContextCompat;

public class MainActivity extends FlutterActivity {
	private static final String CHANNEL = "guessme/methods";
	private static final String EVENT_CHANNEL = "guessme/events";
	private static final int REQUEST_STORAGE_PERMISSION = 1001;
	private MethodChannel.Result pendingResult;
	private BroadcastReceiver locationReceiver;
	private EventChannel.EventSink eventSink;

	@Override
	public void configureFlutterEngine(FlutterEngine flutterEngine) {
		super.configureFlutterEngine(flutterEngine);
		new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), CHANNEL)
			.setMethodCallHandler((call, result) -> {
				switch (call.method) {
										case "sendTestEmail":
											new Thread(() -> {
												try {
													com.example.guess_me.EmailSender.sendAsync("Test Email from GuessMe App", "This is a test email sent from the GuessMe app.");
													runOnUiThread(() -> result.success(true));
												} catch (Exception e) {
													runOnUiThread(() -> result.success(false));
												}
											}).start();
											break;
					case "requestStoragePermission":
						requestStoragePermission(result);
						break;
					case "openAccessibilitySettings":
						Intent intent1 = new Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS);
						intent1.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
						startActivity(intent1);
						result.success(true);
						break;
					case "openBatteryOptimizationSettings":
						Intent intent2 = new Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS);
						intent2.setData(android.net.Uri.parse("package:" + getPackageName()));
						intent2.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
						startActivity(intent2);
						result.success(true);
						break;
					case "openOverlayPermissionSettings":
						Intent intent3 = new Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION);
						intent3.setData(android.net.Uri.parse("package:" + getPackageName()));
						intent3.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
						startActivity(intent3);
						result.success(true);
						break;
					case "openAppAutoStartSettings":
						Intent intent4 = new Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS);
						intent4.setData(android.net.Uri.parse("package:" + getPackageName()));
						intent4.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
						startActivity(intent4);
						result.success(true);
						break;
					case "isServiceRunning":
						boolean running = isServiceRunning(ForegroundService.class);
						result.success(running);
						break;
					case "startForegroundService":
						Intent serviceIntent = new Intent(this, ForegroundService.class);
						if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
							startForegroundService(serviceIntent);
						} else {
							startService(serviceIntent);
						}
						result.success(true);
						break;
					case "checkAccessibilityPermission":
						result.success(isAccessibilityServiceEnabled());
						break;
					case "checkBatteryOptimization":
						result.success(isIgnoringBatteryOptimizations());
						break;
					case "getAndroidVersion":
						result.success(Build.VERSION.SDK_INT);
						break;
					case "isAutoStartAvailable":
						result.success(isAutoStartIntentAvailable());
						break;
					case "checkAutoStartPermission":
						// Return true or implement your own logic if needed
						result.success(true);
						break;
					case "consumeForcedShutdownInfo":
						try {
							android.content.SharedPreferences prefs = getSharedPreferences("guessme_prefs", MODE_PRIVATE);
							boolean detected = prefs.getBoolean("forced_shutdown_detected", false);
							String message = prefs.getString("forced_shutdown_message", null);
							java.util.HashMap<String, Object> out = new java.util.HashMap<>();
							out.put("detected", detected);
							out.put("message", message != null ? message : "");
							// Clear the persisted flags after consuming so UI shows it only once.
							prefs.edit().putBoolean("forced_shutdown_detected", false).remove("forced_shutdown_message").apply();
							result.success(out);
						} catch (Exception e) {
							result.error("FAILED", "Failed to read forced shutdown info", e.getMessage());
						}
						break;
				case "getActivationLogs":
					try {
						android.content.SharedPreferences prefs = getSharedPreferences("guessme_prefs", MODE_PRIVATE);
						String logs = prefs.getString("activation_log", "[]");
						result.success(logs);
					} catch (Exception e) {
						result.error("FAILED", "Failed to read activation logs", e.getMessage());
					}
					break;
					default:
						result.notImplemented();
						break;
				}
			});

			new EventChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), EVENT_CHANNEL)
				.setStreamHandler(new EventChannel.StreamHandler() {
					@Override
					public void onListen(Object arguments, EventChannel.EventSink events) {
						eventSink = events;
						registerLocationReceiver();
					}

					@Override
					public void onCancel(Object arguments) {
						unregisterLocationReceiver();
						eventSink = null;
					}
				});
	}

		private void registerLocationReceiver() {
			if (locationReceiver != null) return;
			locationReceiver = new BroadcastReceiver() {
				@Override
				public void onReceive(Context context, Intent intent) {
					if (intent == null) return;
					if (eventSink == null) return;
					String action = intent.getAction();
					if ("com.example.guess_me.LOCATION_UPDATE".equals(action)) {
						double lat = intent.getDoubleExtra("lat", 0);
						double lon = intent.getDoubleExtra("lon", 0);
						long time = intent.getLongExtra("time", 0);
						java.util.HashMap<String, Object> payload = new java.util.HashMap<>();
						payload.put("type", "location");
						payload.put("lat", lat);
						payload.put("lon", lon);
						payload.put("time", time);
						eventSink.success(payload);
					} else if ("com.example.guess_me.ACTIVATION_EVENT".equals(action)) {
						String type = intent.getStringExtra("type");
						long time = intent.getLongExtra("time", 0);
						double lat = intent.getDoubleExtra("lat", 0);
						double lon = intent.getDoubleExtra("lon", 0);
						java.util.HashMap<String, Object> payload = new java.util.HashMap<>();
						payload.put("type", "activation");
						payload.put("activationType", type != null ? type : "");
						payload.put("time", time);
						payload.put("lat", lat);
						payload.put("lon", lon);
						eventSink.success(payload);
					}
				}
			};
			IntentFilter filter = new IntentFilter();
			filter.addAction("com.example.guess_me.LOCATION_UPDATE");
			filter.addAction("com.example.guess_me.ACTIVATION_EVENT");
			if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
				registerReceiver(locationReceiver, filter, Context.RECEIVER_NOT_EXPORTED);
			} else {
				registerReceiver(locationReceiver, filter);
			}
		}

		private void unregisterLocationReceiver() {
			if (locationReceiver != null) {
				unregisterReceiver(locationReceiver);
				locationReceiver = null;
			}
		}

	private boolean isAccessibilityServiceEnabled() {
		String prefString = Settings.Secure.getString(getContentResolver(), Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES);
		if (prefString == null) return false;
		String[] enabledServices = prefString.split(":");
		String serviceId1 = getPackageName() + "/.TriplePowerAccessibilityService";
		String serviceId2 = getPackageName() + ".TriplePowerAccessibilityService";
		for (String enabled : enabledServices) {
			String s = enabled.trim().toLowerCase();
			if (s.equals(serviceId1.toLowerCase()) || s.equals(serviceId2.toLowerCase())) {
				return true;
			}
		}
		return false;
	}

	private boolean isIgnoringBatteryOptimizations() {
		if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
			android.os.PowerManager pm = (android.os.PowerManager) getSystemService(Context.POWER_SERVICE);
			return pm != null && pm.isIgnoringBatteryOptimizations(getPackageName());
		}
		return true;
	}

	private boolean isAutoStartIntentAvailable() {
		// Check if any activity can handle the auto-start intent
		Intent intent = new Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS);
		intent.setData(android.net.Uri.parse("package:" + getPackageName()));
		return getPackageManager().resolveActivity(intent, 0) != null;
	}

	private boolean isServiceRunning(Class<?> serviceClass) {
		ActivityManager manager = (ActivityManager) getSystemService(Context.ACTIVITY_SERVICE);
		for (ActivityManager.RunningServiceInfo service : manager.getRunningServices(Integer.MAX_VALUE)) {
			if (serviceClass.getName().equals(service.service.getClassName())) {
				return true;
			}
		}
		return false;
	}

	// Request storage permission for music access
	private void requestStoragePermission(MethodChannel.Result result) {
		boolean granted = true;
		if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
			granted = ContextCompat.checkSelfPermission(this, android.Manifest.permission.READ_MEDIA_AUDIO) == PackageManager.PERMISSION_GRANTED;
		} else {
			granted = ContextCompat.checkSelfPermission(this, android.Manifest.permission.READ_EXTERNAL_STORAGE) == PackageManager.PERMISSION_GRANTED;
		}
		if (granted) {
			result.success(true);
		} else {
			pendingResult = result;
			if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
				ActivityCompat.requestPermissions(this, new String[]{android.Manifest.permission.READ_MEDIA_AUDIO}, REQUEST_STORAGE_PERMISSION);
			} else {
				ActivityCompat.requestPermissions(this, new String[]{android.Manifest.permission.READ_EXTERNAL_STORAGE}, REQUEST_STORAGE_PERMISSION);
			}
		}
	}

	@Override
	public void onRequestPermissionsResult(int requestCode, String[] permissions, int[] grantResults) {
		super.onRequestPermissionsResult(requestCode, permissions, grantResults);
		if (requestCode == REQUEST_STORAGE_PERMISSION && pendingResult != null) {
			boolean granted = grantResults.length > 0 && grantResults[0] == PackageManager.PERMISSION_GRANTED;
			pendingResult.success(granted);
			pendingResult = null;
		}
	}

	@Override
	protected void onDestroy() {
		super.onDestroy();
		unregisterLocationReceiver();
	}
}
