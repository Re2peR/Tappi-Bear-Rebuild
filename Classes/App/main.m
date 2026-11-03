//
//  main.m
//  Tappi Bear — arm64 兼容移植
//
//  原版 All_In_One 是 32 位 armv6/armv7s + cocos2d-iphone 1.x。
//  iOS 11 起系统不再加载 32 位进程，因此必须重新编译出 arm64。
//

#import <UIKit/UIKit.h>
#import "TBAppDelegate.h"

int main(int argc, char *argv[])
{
    @autoreleasepool {
        return UIApplicationMain(argc, argv, nil, NSStringFromClass([TBAppDelegate class]));
    }
}
