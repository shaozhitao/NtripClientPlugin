#import <Cordova/CDV.h>

@interface NtripClient : CDVPlugin <NSStreamDelegate>

- (void)startNtripClient:(CDVInvokedUrlCommand *)command;
- (void)stopNtripClient:(CDVInvokedUrlCommand *)command;
- (void)getConnectionStatus:(CDVInvokedUrlCommand *)command;
- (void)getConnectionInfo:(CDVInvokedUrlCommand *)command;
- (void)sendGngga:(CDVInvokedUrlCommand *)command;
- (void)registerOnData:(CDVInvokedUrlCommand *)command;
- (void)registerOnError:(CDVInvokedUrlCommand *)command;
- (void)registerOnClose:(CDVInvokedUrlCommand *)command;
- (void)registerOnRTCM:(CDVInvokedUrlCommand *)command;
- (void)getMountPointList:(CDVInvokedUrlCommand *)command;

@end