#import "NtripClient.h"

@implementation NtripClient

- (void)pluginInitialize {
    self.isConnected = NO;
    self.shouldReconnect = NO;
    self.reconnectAttempts = 0;
}

#pragma mark - API 实现

- (void)startNtripClient:(CDVInvokedUrlCommand*)command {
    self.ip        = [command.arguments objectAtIndex:0];
    self.port      = [[command.arguments objectAtIndex:1] intValue];
    self.username  = [command.arguments objectAtIndex:2];
    self.password  = [command.arguments objectAtIndex:3];
    self.gngga     = [command.arguments objectAtIndex:4];
    self.mountPoint= [command.arguments objectAtIndex:5];

    self.shouldReconnect = YES;
    self.reconnectAttempts = 0;

    [self connectToServer:command.callbackId];
}

- (void)connectToServer:(NSString *)callbackId {
    if (self.isConnected) return;

    CFReadStreamRef readStream;
    CFWriteStreamRef writeStream;
    CFStreamCreatePairWithSocketToHost(NULL, (__bridge CFStringRef)self.ip, self.port, &readStream, &writeStream);

    self.inputStream = (__bridge_transfer NSInputStream*)readStream;
    self.outputStream = (__bridge_transfer NSOutputStream*)writeStream;

    self.inputStream.delegate = self;
    self.outputStream.delegate = self;

    [self.inputStream scheduleInRunLoop:[NSRunLoop mainRunLoop] forMode:NSDefaultRunLoopMode];
    [self.outputStream scheduleInRunLoop:[NSRunLoop mainRunLoop] forMode:NSDefaultRunLoopMode];

    [self.inputStream open];
    [self.outputStream open];
}

- (void)stopNtripClient:(CDVInvokedUrlCommand*)command {
    self.shouldReconnect = NO;
    [self.reconnectTimer invalidate];
    [self.inputStream close];
    [self.outputStream close];
    self.isConnected = NO;

    CDVPluginResult* result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:@"NTRIP 客户端已停止"];
    [self.commandDelegate sendPluginResult:result callbackId:command.callbackId];

    if (self.onCloseCallbackId) {
        CDVPluginResult *closeResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:@"NTRIP 客户端已停止"];
        [closeResult setKeepCallbackAsBool:YES];
        [self.commandDelegate sendPluginResult:closeResult callbackId:self.onCloseCallbackId];
    }
}

- (void)getConnectionStatus:(CDVInvokedUrlCommand*)command {
    CDVPluginResult* result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsBool:self.isConnected];
    [self.commandDelegate sendPluginResult:result callbackId:command.callbackId];
}

- (void)getConnectionInfo:(CDVInvokedUrlCommand*)command {
    NSMutableDictionary *info = [NSMutableDictionary dictionary];
    [info setValue:self.ip forKey:@"ip"];
    [info setValue:@(self.port) forKey:@"port"];
    CDVPluginResult* result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:info];
    [self.commandDelegate sendPluginResult:result callbackId:command.callbackId];
}

- (void)sendGngga:(CDVInvokedUrlCommand*)command {
    if (self.isConnected && self.outputStream) {
        NSData *data = [[command.arguments objectAtIndex:0] dataUsingEncoding:NSUTF8StringEncoding];
        [self.outputStream write:data.bytes maxLength:data.length];
        CDVPluginResult* result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:@"GNGGA 发送成功"];
        [self.commandDelegate sendPluginResult:result callbackId:command.callbackId];
    } else {
        CDVPluginResult* result = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"未连接"];
        [self.commandDelegate sendPluginResult:result callbackId:command.callbackId];
    }
}

- (void)getMountPointList:(CDVInvokedUrlCommand *)command {
    NSString *ip = [command.arguments objectAtIndex:0];
    NSNumber *portNumber = [command.arguments objectAtIndex:1];
    int port = [portNumber intValue];

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        @try {
            // 创建 socket 连接
            CFReadStreamRef readStream;
            CFWriteStreamRef writeStream;
            CFStreamCreatePairWithSocketToHost(NULL, (__bridge CFStringRef)ip, port, &readStream, &writeStream);

            NSInputStream *inputStream = (__bridge_transfer NSInputStream *)readStream;
            NSOutputStream *outputStream = (__bridge_transfer NSOutputStream *)writeStream;

            [inputStream open];
            [outputStream open];

            // 构造 Sourcetable 请求
            NSString *request =
                @"GET / HTTP/1.1\r\n"
                @"User-Agent: NTRIP iOS Client\r\n"
                @"Host: %@\r\n"
                @"Accept: */*\r\n"
                @"Connection: close\r\n\r\n";
            NSString *reqString = [NSString stringWithFormat:request, ip];
            NSData *reqData = [reqString dataUsingEncoding:NSUTF8StringEncoding];
            [outputStream write:reqData.bytes maxLength:reqData.length];

            NSMutableData *responseData = [NSMutableData data];
            uint8_t buffer[1024];
            NSInteger len;

            while ((len = [inputStream read:buffer maxLength:sizeof(buffer)]) > 0) {
                [responseData appendBytes:buffer length:len];
            }

            [inputStream close];
            [outputStream close];

            NSString *response = [[NSString alloc] initWithData:responseData encoding:NSUTF8StringEncoding];
            NSArray *lines = [response componentsSeparatedByString:@"\n"];
            BOOL inSourceTable = NO;
            NSMutableArray *mountPoints = [NSMutableArray array];

            for (NSString *line in lines) {
                NSString *trimmed = [line stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];

                if ([trimmed hasPrefix:@"SOURCETABLE"]) {
                    inSourceTable = YES;
                } else if ([trimmed hasPrefix:@"ENDSOURCETABLE"]) {
                    break;
                } else if (inSourceTable && [trimmed hasPrefix:@"STR"]) {
                    NSArray *parts = [trimmed componentsSeparatedByString:@";"];
                    if (parts.count > 1) {
                        [mountPoints addObject:parts[1]];
                    }
                }
            }

            CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsArray:mountPoints];
            [self.commandDelegate sendPluginResult:result callbackId:command.callbackId];
        }
        @catch (NSException *exception) {
            CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:exception.reason];
            [self.commandDelegate sendPluginResult:result callbackId:command.callbackId];
        }
    });
}


#pragma mark - NSStreamDelegate

- (void)stream:(NSStream *)aStream handleEvent:(NSStreamEvent)eventCode {
    switch (eventCode) {
        case NSStreamEventOpenCompleted: {
            self.isConnected = YES;
            self.reconnectAttempts = 0;
            [self sendNtripRequest];
            if (self.onDataCallbackId) {
                CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:@"成功连接到 NTRIP 服务器"];
                [result setKeepCallbackAsBool:YES];
                [self.commandDelegate sendPluginResult:result callbackId:self.onDataCallbackId];
            }
        } break;
        case NSStreamEventHasBytesAvailable: {
            uint8_t buffer[4096];
            NSInteger len = [self.inputStream read:buffer maxLength:sizeof(buffer)];
            if (len > 0 && self.onRTCMCallbackId) {
                NSData *data = [NSData dataWithBytes:buffer length:len];
                CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsArrayBuffer:data];
                [result setKeepCallbackAsBool:YES];
                [self.commandDelegate sendPluginResult:result callbackId:self.onRTCMCallbackId];
            }
        } break;
        case NSStreamEventErrorOccurred: {
            self.isConnected = NO;
            if (self.onErrorCallbackId) {
                CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:aStream.streamError.localizedDescription];
                [result setKeepCallbackAsBool:YES];
                [self.commandDelegate sendPluginResult:result callbackId:self.onErrorCallbackId];
            }
        } break;
        case NSStreamEventEndEncountered: {
            self.isConnected = NO;
            if (self.onCloseCallbackId) {
                CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:@"连接已关闭"];
                [result setKeepCallbackAsBool:YES];
                [self.commandDelegate sendPluginResult:result callbackId:self.onCloseCallbackId];
            }
        } break;
        default: break;
    }
}

#pragma mark - Private

- (void)sendNtripRequest {
    NSString *auth = [NSString stringWithFormat:@"%@:%@", self.username, self.password];
    NSData *authData = [auth dataUsingEncoding:NSUTF8StringEncoding];
    NSString *base64Auth = [authData base64EncodedStringWithOptions:0];

    NSString *req = [NSString stringWithFormat:
                     @"GET /%@ HTTP/1.1\r\n"
                     @"User-Agent: NTRIP iOS Client\r\n"
                     @"Host: %@:%d\r\n"
                     @"Authorization: Basic %@\r\n"
                     @"Accept: */*\r\n"
                     @"Connection: close\r\n\r\n",
                     self.mountPoint, self.ip, self.port, base64Auth];

    NSData *data = [req dataUsingEncoding:NSUTF8StringEncoding];
    [self.outputStream write:data.bytes maxLength:data.length];

    if (self.gngga) {
        NSData *ggaData = [self.gngga dataUsingEncoding:NSUTF8StringEncoding];
        [self.outputStream write:ggaData.bytes maxLength:ggaData.length];
    }
}

#pragma mark - 注册回调

- (void)registerOnData:(CDVInvokedUrlCommand*)command {
    self.onDataCallbackId = command.callbackId;
    CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_NO_RESULT];
    [pluginResult setKeepCallbackAsBool:YES];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void)registerOnRTCM:(CDVInvokedUrlCommand*)command {
    self.onRTCMCallbackId = command.callbackId;
    CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_NO_RESULT];
    [pluginResult setKeepCallbackAsBool:YES];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void)registerOnError:(CDVInvokedUrlCommand*)command {
    self.onErrorCallbackId = command.callbackId;
    CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_NO_RESULT];
    [pluginResult setKeepCallbackAsBool:YES];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void)registerOnClose:(CDVInvokedUrlCommand*)command {
    self.onCloseCallbackId = command.callbackId;
    CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_NO_RESULT];
    [pluginResult setKeepCallbackAsBool:YES];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

@end
