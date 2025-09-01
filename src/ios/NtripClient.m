#import "NtripClient.h"
#import <Cordova/CDV.h>

@implementation NtripClient {
    CDVPlugin *_plugin;
    NSInputStream *_inputStream;
    NSOutputStream *_outputStream;
    NSString *_ip;
    int _port;
    NSString *_username;
    NSString *_password;
    NSString *_mountPoint;
    BOOL _isConnected;
    BOOL _shouldReconnect;
    int _reconnectAttempts;
    NSTimer *_reconnectTimer;
}

- (void)pluginInitialize {
    [super pluginInitialize];
    _isConnected = NO;
    _shouldReconnect = NO;
    _reconnectAttempts = 0;
}

- (void)startNtripClient:(CDVInvokedUrlCommand *)command {
    _ip = [command.arguments objectAtIndex:0];
    _port = [[command.arguments objectAtIndex:1] intValue];
    _username = [command.arguments objectAtIndex:2];
    _password = [command.arguments objectAtIndex:3];
    NSString *gngga = [command.arguments objectAtIndex:4];
    _mountPoint = [command.arguments objectAtIndex:5];
    _shouldReconnect = YES;
    _reconnectAttempts = 0;
    
    [self connectToServer:command.callbackId];
}

- (void)connectToServer:(NSString *)callbackId {
    if (_isConnected) {
        [self sendSuccessResult:@"Already connected" callbackId:callbackId];
        return;
    }
    
    CFReadStreamRef readStream;
    CFWriteStreamRef writeStream;
    CFStreamCreatePairWithSocketToHost(NULL, (__bridge CFStringRef)_ip, _port, &readStream, &writeStream);
    
    _inputStream = (__bridge NSInputStream *)readStream;
    _outputStream = (__bridge NSOutputStream *)writeStream;
    
    _inputStream.delegate = self;
    _outputStream.delegate = self;
    
    [_inputStream scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
    [_outputStream scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
    
    [_inputStream open];
    [_outputStream open];
}

- (void)stream:(NSStream *)stream handleEvent:(NSStreamEvent)eventCode {
    switch (eventCode) {
        case NSStreamEventOpenCompleted:
            [self handleConnectionOpen];
            break;
        case NSStreamEventHasBytesAvailable:
            [self handleIncomingData];
            break;
        case NSStreamEventErrorOccurred:
            [self handleStreamError:stream.streamError];
            break;
        case NSStreamEventEndEncountered:
            [self handleConnectionClose];
            break;
        default:
            break;
    }
}

- (void)handleConnectionOpen {
    _isConnected = YES;
    _reconnectAttempts = 0;
    [self sendNtripRequest];
    
    CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:@"成功连接到NTRIP服务器"];
    [self.commandDelegate sendPluginResult:result callbackId:@"onData"];
}

- (void)sendNtripRequest {
    NSString *authString = [NSString stringWithFormat:@"%@:%@", _username, _password];
    NSData *authData = [authString dataUsingEncoding:NSUTF8StringEncoding];
    NSString *base64Auth = [authData base64EncodedStringWithOptions:0];
    
    NSString *request = [NSString stringWithFormat:
                        @"GET /%@ HTTP/1.1\r\n"
                        @"User-Agent: NTRIP iOS Client\r\n"
                        @"Host: %@:%d\r\n"
                        @"Authorization: Basic %@\r\n"
                        @"Accept: */*\r\n"
                        @"Connection: close\r\n\r\n",
                        _mountPoint, _ip, _port, base64Auth];
    
    NSData *requestData = [request dataUsingEncoding:NSUTF8StringEncoding];
    [_outputStream write:requestData.bytes maxLength:requestData.length];
}

- (void)handleIncomingData {
    uint8_t buffer[1024];
    NSInteger bytesRead = [_inputStream read:buffer maxLength:sizeof(buffer)];
    
    if (bytesRead > 0) {
        NSData *data = [NSData dataWithBytes:buffer length:bytesRead];
        CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsArrayBuffer:data];
        [result setKeepCallbackAsBool:YES];
        [self.commandDelegate sendPluginResult:result callbackId:@"onRTCM"];
    }
}

// 其他必要方法实现（错误处理、重连逻辑、数据发送等）
- (void)handleStreamError:(NSError *)error {
    _isConnected = NO;
    CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:error.localizedDescription];
    [self.commandDelegate sendPluginResult:result callbackId:@"onError"];
    
    [self attemptReconnect];
}

- (void)handleConnectionClose {
    _isConnected = NO;
    CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:@"连接已关闭"];
    [self.commandDelegate sendPluginResult:result callbackId:@"onClose"];
    
    [self attemptReconnect];
}

- (void)attemptReconnect {
    if (_shouldReconnect && _reconnectAttempts < 5) {
        _reconnectAttempts++;
        _reconnectTimer = [NSTimer scheduledTimerWithTimeInterval:5.0
                                                           target:self
                                                         selector:@selector(reconnect)
                                                         userInfo:nil
                                                          repeats:NO];
    }
}

- (void)reconnect {
    [self connectToServer:nil];
}

// 其他API方法实现
- (void)stopNtripClient:(CDVInvokedUrlCommand *)command {
    _shouldReconnect = NO;
    [_reconnectTimer invalidate];
    [_inputStream close];
    [_outputStream close];
    _isConnected = NO;
    
    CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:@"已停止NTRIP客户端"];
    [self.commandDelegate sendPluginResult:result callbackId:command.callbackId];
}

- (void)getConnectionStatus:(CDVInvokedUrlCommand *)command {
    CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsBool:_isConnected];
    [self.commandDelegate sendPluginResult:result callbackId:command.callbackId];
}

// 实现其他必要方法...

@end