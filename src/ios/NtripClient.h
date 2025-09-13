#import <Cordova/CDVPlugin.h>

@interface NtripClient : CDVPlugin <NSStreamDelegate>

@property (nonatomic, strong) NSInputStream *inputStream;
@property (nonatomic, strong) NSOutputStream *outputStream;
@property (nonatomic, strong) NSTimer *reconnectTimer;

@property (nonatomic, copy) NSString *ip;
@property (nonatomic, assign) int port;
@property (nonatomic, copy) NSString *username;
@property (nonatomic, copy) NSString *password;
@property (nonatomic, copy) NSString *mountPoint;
@property (nonatomic, copy) NSString *gngga;

@property (nonatomic, assign) BOOL isConnected;
@property (nonatomic, assign) BOOL shouldReconnect;
@property (nonatomic, assign) int reconnectAttempts;

@property (nonatomic, copy) NSString *onDataCallbackId;
@property (nonatomic, copy) NSString *onRTCMCallbackId;
@property (nonatomic, copy) NSString *onErrorCallbackId;
@property (nonatomic, copy) NSString *onCloseCallbackId;

- (void)startNtripClient:(CDVInvokedUrlCommand*)command;
- (void)stopNtripClient:(CDVInvokedUrlCommand*)command;
- (void)getConnectionStatus:(CDVInvokedUrlCommand*)command;
- (void)getConnectionInfo:(CDVInvokedUrlCommand*)command;
- (void)sendGngga:(CDVInvokedUrlCommand*)command;
- (void)getMountPointList:(CDVInvokedUrlCommand*)command;

// 注册回调
- (void)registerOnData:(CDVInvokedUrlCommand*)command;
- (void)registerOnRTCM:(CDVInvokedUrlCommand*)command;
- (void)registerOnError:(CDVInvokedUrlCommand*)command;
- (void)registerOnClose:(CDVInvokedUrlCommand*)command;

@end
