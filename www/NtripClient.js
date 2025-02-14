var exec = require('cordova/exec');

var NtripClient = {
    startNtripClient: function(ip, port, username, password, gngga, successCallback, errorCallback) {
        exec(successCallback, errorCallback, 'NtripClient', 'startNtripClient', [ip, port, username, password, gngga]);
    },
    stopNtripClient: function(successCallback, errorCallback) {
        exec(successCallback, errorCallback, 'NtripClient', 'stopNtripClient', []);
    },
    getConnectionStatus: function(successCallback, errorCallback) {
        exec(successCallback, errorCallback, 'NtripClient', 'getConnectionStatus', []);
    },
    getConnectionInfo: function(successCallback, errorCallback) {
        exec(successCallback, errorCallback, 'NtripClient', 'getConnectionInfo', []);
    },
    sendGngga: function(gngga, successCallback, errorCallback) {
        exec(successCallback, errorCallback, 'NtripClient', 'sendGngga', [gngga]);
    },
    registerOnData: function(callback) {
      exec(callback, null, 'NtripClient', 'registerOnData', []);
    },
    registerOnError: function(callback) {
      exec(callback, null, 'NtripClient', 'registerOnError', []);
    },
    registerOnClose: function(callback) {
      exec(callback, null, 'NtripClient', 'registerOnClose', []);
    },
    registerOnRTCM: function(callback) {
      exec(callback, null, 'NtripClient', 'registerOnRTCM', []);
    }
};

module.exports = NtripClient;
