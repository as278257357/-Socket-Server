//
//  Server.h
//  基于服务发现的Socket的Server
//
//  Created by EaseMob on 16/5/13.
//  Copyright © 2016年 EaseMob. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface Server : NSObject<NSNetServiceDelegate,NSStreamDelegate>
@property (nonatomic, strong) NSNetService *service;
@property (nonatomic, strong) NSSocketPort *socket;
@property (nonatomic, strong) NSInputStream *inputStream;
@property (nonatomic, strong) NSOutputStream *outputStream;
@property (nonatomic, assign) int port;

@end
