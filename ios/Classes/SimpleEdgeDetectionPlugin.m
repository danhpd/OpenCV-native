#import "SimpleEdgeDetectionPlugin.h"
#if __has_include(<opencv/opencv-Swift.h>)
#import <opencv/opencv-Swift.h>
#else
// Support project import fallback if the generated compatibility header
// is not copied when this plugin is created as a library.
// https://forums.swift.org/t/swift-static-libraries-dont-copy-generated-objective-c-header/19816
#import "opencv-Swift.h"
#endif

@implementation SimpleEdgeDetectionPlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
  [SwiftSimpleEdgeDetectionPlugin registerWithRegistrar:registrar];
}
@end
