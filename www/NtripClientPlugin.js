var exec = require('cordova/exec');

var NtripClient = {
    startNtripClient: function(ip, port, username, password, gngga, successCallback, errorCallback) {
        exec(successCallback, errorCallback, 'NtripSocketClientPlugin', 'startNtripClient', [ip, port, username, password, gngga]);
    },
    stopNtripClient: function(successCallback, errorCallback) {
        exec(successCallback, errorCallback, 'NtripSocketClientPlugin', 'stopNtripClient', []);
    },
    getConnectionStatus: function(successCallback, errorCallback) {
        exec(successCallback, errorCallback, 'NtripSocketClientPlugin', 'getConnectionStatus', []);
    },
    getConnectionInfo: function(successCallback, errorCallback) {
        exec(successCallback, errorCallback, 'NtripSocketClientPlugin', 'getConnectionInfo', []);
    },
    sendGngga: function(gngga, successCallback, errorCallback) {
        exec(successCallback, errorCallback, 'NtripSocketClientPlugin', 'sendGngga', [gngga]);
    }
};

module.exports = NtripClient;