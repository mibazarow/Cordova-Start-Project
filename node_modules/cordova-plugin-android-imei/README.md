# cordova-plugin-android-imei

Cordova plugin for retrieving IMEI of the device.

    cordova plugin add cordova-plugin-android-imei

## Usage

The plugin uses the [getDeviceId](https://developer.android.com/reference/android/telephony/TelephonyManager.html#getDeviceId()) method of the *TelephonyManager* instance to retrieve the IMEI.

```javascript
cordova.plugins.IMEI(function (err, imei) {
  console.log('imei', imei)
})
```
