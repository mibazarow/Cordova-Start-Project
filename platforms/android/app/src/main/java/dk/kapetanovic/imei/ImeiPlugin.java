package dk.kapetanovic.imei;

import android.Manifest;
import android.content.Context;
import android.content.pm.PackageManager;
import android.telephony.TelephonyManager;
import android.text.TextUtils;

import org.apache.cordova.CallbackContext;
import org.apache.cordova.CordovaInterface;
import org.apache.cordova.CordovaPlugin;
import org.apache.cordova.CordovaWebView;
import org.apache.cordova.PluginResult;
import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

import java.util.ArrayList;
import java.util.List;

public class ImeiPlugin extends CordovaPlugin {
    private static final String READ_PHONE_STATE = Manifest.permission.READ_PHONE_STATE;
    private static final int REQUEST_CODE_DEVICE_ID = 0;

    private TelephonyManager telephonyManager;
    private final List<CallbackContext> deviceIdCallbacks = new ArrayList<CallbackContext>();

    @Override
    public void initialize(CordovaInterface cordova, CordovaWebView webView) {
        super.initialize(cordova, webView);

        this.telephonyManager = (TelephonyManager) cordova.getActivity()
                .getApplication()
                .getApplicationContext()
                .getSystemService(Context.TELEPHONY_SERVICE);
    }

    @Override
    public boolean execute(String action, JSONArray args, CallbackContext callbackContext) throws JSONException {
        getDeviceId(callbackContext);
        return true;
    }

    @Override
    public void onRequestPermissionResult(int requestCode, String[] permissions, int[] grantResults) throws JSONException {
        if (requestCode == REQUEST_CODE_DEVICE_ID) {
            boolean hasPermission = true;

            for(int result : grantResults) {
                hasPermission = hasPermission && result == PackageManager.PERMISSION_GRANTED;
            }

            synchronized(deviceIdCallbacks) {
                if(hasPermission) {
                    for(CallbackContext callbackContext : deviceIdCallbacks) {
                        getDeviceIdWithPermission(callbackContext);
                    }
                } else {
                    String message = "Permission denied " + TextUtils.join(", ", permissions);
                    for(CallbackContext callbackContext : deviceIdCallbacks) {
                        callbackContext.sendPluginResult(ERROR(message));
                    }
                }

                deviceIdCallbacks.clear();
            }
        }
    }

    private void getDeviceId(CallbackContext callbackContext) throws JSONException {
        if (hasPermission()) {
            getDeviceIdWithPermission(callbackContext);
        } else {
            synchronized (deviceIdCallbacks) {
                if (hasPermission()) {
                    getDeviceIdWithPermission(callbackContext);
                    return;
                }

                deviceIdCallbacks.add(callbackContext);

                if (deviceIdCallbacks.size() == 1) {
                    cordova.requestPermission(this, REQUEST_CODE_DEVICE_ID, READ_PHONE_STATE);
                }
            }
        }
    }

    private void getDeviceIdWithPermission(CallbackContext callbackContext) throws JSONException {
        String id = telephonyManager.getDeviceId();
        callbackContext.sendPluginResult(OK(id));
    }

    private boolean hasPermission() {
        return cordova.hasPermission(READ_PHONE_STATE);
    }

    private static PluginResult OK(Object obj) throws JSONException {
        return createPluginResult(obj, PluginResult.Status.OK);
    }

    private static PluginResult ERROR(Object obj) throws JSONException {
        return createPluginResult(obj, PluginResult.Status.ERROR);
    }

    private static PluginResult createPluginResult(Object obj, PluginResult.Status status) throws JSONException {
        JSONObject json = new JSONObject();
        json.put("data", obj == null ? JSONObject.NULL : obj);
        return new PluginResult(status, json);
    }
}
