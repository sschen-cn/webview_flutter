//
//  FlutterWebView+JSBridge.m
//  Pods-Runner
//
//  Created by ganliangdong on 2019/10/2.
//

#import "FlutterWebView+JSBridge.h"
#import "WKWebViewJavascriptBridge.h"
#import "JavaScriptChannelHandler.h"

#import <objc/runtime.h>

static id JSBridgeKey;


@interface FLTWebViewController(JSBridge)

@property (nonatomic,copy)WKWebViewJavascriptBridge* bridge;


@end

@implementation  FLTWebViewController(JSBridge)

- (WKWebViewJavascriptBridge *)bridge
{
    WKWebViewJavascriptBridge *bridge = (WKWebViewJavascriptBridge*)objc_getAssociatedObject(self, &JSBridgeKey);
    if (!bridge) {
        WKWebView* webView = (WKWebView*)self.view;
        if (webView && [webView isKindOfClass:[WKWebView class]]) {
            bridge = [WKWebViewJavascriptBridge bridgeForWebView:webView];
            [self setBridge:bridge];
        }
    }
    return bridge;
}

- (void)setBridge:(WKWebViewJavascriptBridge *)bridge
{
    objc_setAssociatedObject(self, &JSBridgeKey, bridge, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (FlutterMethodChannel*)getChannel
{
    Ivar iVar = class_getInstanceVariable([self class], [@"_channel" UTF8String]);
    id propertyVal = object_getIvar(self, iVar);
    return propertyVal;
}









+(void)load{
    
    Class class = NSClassFromString(@"FLTWebViewController");
    Method m1 = class_getInstanceMethod(class, @selector(onMethodCall:result:));
    Method m2 = class_getInstanceMethod(class, @selector(bridge_onMethodCall:result:));
    method_exchangeImplementations(m1, m2);
}

- (void)bridge_onMethodCall:(FlutterMethodCall*)call result:(FlutterResult)result {
  if([[call method] isEqualToString:@"registerHandler"]){
    [self registerHandler:call result:result];
  } else if([[call method] isEqualToString:@"callHandler"]){
      [self callHandler:call result:result];
  } else {
      [self bridge_onMethodCall:call result:result];
  }
}




-(void) registerHandler:(FlutterMethodCall* )call result:(FlutterResult)result{
    NSLog(@"registerHandler:%@",self.bridge);
    if (self.bridge != nil) {
        NSDictionary* dic = [call arguments];
        NSString* handlerName = [dic valueForKey:@"handlerName"];
        if (handlerName != nil) {
            FlutterMethodChannel* channel = [self getChannel];
            __weak __typeof__(channel) weakChannel = channel;
            [self.bridge registerHandler:handlerName handler:^(id data, WVJBResponseCallback responseCallback) {
                WVJBResponseCallback callback = responseCallback?[responseCallback copy]:nil;
                NSLog(@"%@ callback:%@",handlerName,callback);
                NSMutableDictionary* args=[NSMutableDictionary dictionary];
                [args setValue:handlerName forKey:@"handlerName"];
                if (data) {
                    [args setValue:data forKey:@"data"];
                }
                if(weakChannel != nil){
                  [weakChannel invokeMethod:@"jsBridge" arguments:args result:^(id  _Nullable response) {
                    NSLog(@"jsbridgecall response %@",response);
                    if (response && [response isKindOfClass:[FlutterError class]]) {
                        FlutterError* error = (FlutterError*)response;
                        NSLog(@"err:%@\n%@\n%@\n%@",error.code,error.message,error.details,error.description);
                    }else{
                        if (callback) {
                            callback(response);
                        }
                    }
                  }];
                }
                
            }];
            result([NSString stringWithFormat:@"registerHandler %@ success",handlerName]);
        } else {
            result([FlutterError
                errorWithCode:@"registerBridge_failed"
                      message:@"handlerName is nil"
                      details:nil]);
        }
    } else {
      result([FlutterError
          errorWithCode:@"registerBridge_failed"
                message:@"bridge or webview is nil"
                details:nil]);
    }
}

-(void) callHandler:(FlutterMethodCall* )call result:(FlutterResult)result{
    
    if (self.bridge != nil) {
        NSDictionary* dic = [call arguments];
        NSString* handlerName = [dic valueForKey:@"handlerName"];
        NSString* data = [dic valueForKey:@"data"];
        if (handlerName != nil) {
            FlutterMethodChannel* channel = [self getChannel];
            __weak __typeof__(channel) weakChannel = channel;
            [self.bridge callHandler:handlerName data:data responseCallback:^(id responseData) {
                NSLog(@"callHandlerResponse %@ ",responseData);
                if(weakChannel != nil){
                    NSMutableDictionary* args=[NSMutableDictionary dictionary];
                    [args setValue:handlerName forKey:@"handlerName"];
                    if (data) {
                        [args setValue:data forKey:@"data"];
                    }
                    [weakChannel invokeMethod:@"jsBridgeCall" arguments:args];
                }
            }];
            result([NSString stringWithFormat:@"callHandler %@ success",handlerName]);
        } else {
            result([FlutterError
                errorWithCode:@"callHandler_failed"
                      message:@"handlerName is nil"
                      details:nil]);
        }
    } else {
      result([FlutterError
          errorWithCode:@"callHandler_failed"
                message:@"bridge or webview is nil"
                details:nil]);
    }
    
}








@end
 


