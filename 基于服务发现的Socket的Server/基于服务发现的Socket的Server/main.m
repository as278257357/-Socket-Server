//
//  main.m
//  基于服务发现的Socket的Server
//
//  Created by EaseMob on 16/5/13.
//  Copyright © 2016年 EaseMob. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "Server.h"

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        
        Server *server = [[Server alloc]init];
        CFRunLoopRun();
        
    }
    return 0;
}
