//
//  Server.m
//  基于服务发现的Socket的Server
//
//  Created by EaseMob on 16/5/13.
//  Copyright © 2016年 EaseMob. All rights reserved.
//

#import "Server.h"
#include <sys/socket.h>
#include <netinet/in.h>

void AcceptCallBack(CFSocketRef, CFSocketCallBackType, CFDateRef, const void *, void *);
void WriteStreamClientCallBack(CFWriteStreamRef stream, CFStreamEventType eventType, void *);
void ReadStreamClientCallBack(CFReadStreamRef stream,CFStreamEventType eventType, void *);

@implementation Server

void AcceptCallBack(CFSocketRef socket, CFSocketCallBackType type, CFDateRef address, const void * data, void * info) {
    CFReadStreamRef readStream = NULL;
    CFWriteStreamRef writeStream = NULL;
    /* data 参数的含义是，如果回调的类型是kCFSocketAcceptCallBack，data就是CFSocketBativeHandle 类型的指针 */
    CFSocketNativeHandle sock =  * (CFSocketNativeHandle *)data;
    
    /* 创建读写 Socket 流 */
    CFStreamCreatePairWithSocket(kCFAllocatorDefault, sock, &readStream, &writeStream);
    if (!readStream || !writeStream) {
        close(sock);
        fprintf(stderr, "CFStreamCreatPairWithSocket()失败\n");
        return;
    }
    CFStreamClientContext streamCtxt = {0, NULL, NULL, NULL, NULL};
    //注册俩种回调函数
    CFReadStreamSetClient(readStream, kCFStreamEventHasBytesAvailable, ReadStreamClientCallBack, &streamCtxt);
    CFWriteStreamSetClient(writeStream, kCFStreamEventCanAcceptBytes, WriteStreamClientCallBack, &streamCtxt);
    
    /* 加入到循环中 */
    CFReadStreamScheduleWithRunLoop(readStream, CFRunLoopGetCurrent(), kCFRunLoopCommonModes);
    CFWriteStreamScheduleWithRunLoop(writeStream, CFRunLoopGetCurrent(), kCFRunLoopCommonModes);
    CFReadStreamOpen(readStream);
    CFWriteStreamOpen(writeStream);
}

/* 读取流操作 客户端有数据过来的时候调用 */
void ReadStreamClientCallBack (CFReadStreamRef stream, CFStreamEventType eventType, void *clientCallBackInfo) {
    UInt8 buff[255];
    CFReadStreamRef inputStream = stream;
    if (NULL != inputStream) {
        CFReadStreamRead(stream, buff, 255);
        printf("接收到数据：%s \n",buff);
        CFReadStreamClose(inputStream);
        CFReadStreamUnscheduleFromRunLoop(inputStream, CFRunLoopGetCurrent(), kCFRunLoopCommonModes);
        inputStream = NULL;
    }
}

/* 写入流 客户端在读取数据是调用 */
void WriteStreamClientCallBack(CFWriteStreamRef stream, CFStreamEventType eventType, void * clientCallBackInfo) {
    CFWriteStreamRef outputStream = stream;
    //输出
    UInt8 buff[] = "Hello Client";
    if (NULL != outputStream) {
        CFWriteStreamWrite(outputStream, buff,strlen((const char *)buff +1));
        CFWriteStreamClose(outputStream);
        CFWriteStreamUnscheduleFromRunLoop(outputStream, CFRunLoopGetCurrent(), kCFRunLoopCommonModes);
        outputStream = NULL;
    }
}

- (id)init {
    BOOL succeed = [self startServer];
    if (succeed) {
        //通过Bonjour 发布服务
        succeed = [self publishServer];
    } else {
        NSLog(@"服务器启动失败");
    }
    return self;
}

- (BOOL) startServer {
    /* 定义一个 Server Socket 引用 */
    CFSocketRef sserver;
    /* 创建 socket context */
    CFSocketContext CTX = {0, ((__bridge void *)self), NULL, NULL, NULL};
    /* 创建 server socket TCP IPv4 设置回调函数 */
    sserver = CFSocketCreate(NULL, PF_INET, SOCK_STREAM,IPPROTO_TCP, kCFSocketAcceptCallBack, (CFSocketCallBack)AcceptCallBack, &CTX);
    if (sserver == NULL) {
        return NO;
    }
    /* 设置是否重新绑定标志 */
    int yes = 1;
    /* 设置socket 属性，SOL_SOCKET 设置tcp SO_REUSEADDR 是重新绑定*/
    setsockopt(CFSocketGetNative(sserver), SOL_SOCKET, SO_REUSEADDR, (void *)&yes, sizeof(yes));
    struct sockaddr_in addr;
    memset(&addr, 0, sizeof(addr));//memset 函数对指定的地址进行内存复制
    addr.sin_len = sizeof(addr);
    addr.sin_family = AF_INET;//AF_INET是设置IPv4
    addr.sin_port = 0;//htons（PORT）无符号短整形数转换成“网络字节序”
    addr.sin_addr.s_addr = htonl(INADDR_ANY);
    /* 从指定字节缓冲区复制，一个不可变的CFData 对象 */
    CFDataRef address = CFDataCreate(kCFAllocatorDefault, (UInt8 *)&addr, sizeof(addr));
    /* 设置Socket */
    if (CFSocketSetAddress(sserver, (CFDataRef)address) != kCFSocketSuccess) {
        fprintf(stderr, "socket 绑定失败\n");
        CFRelease(sserver);
        return NO;
    }
    //通过Bonjour 广播服务器时使用
    NSData *sockerAddressActualData = (__bridge NSData *)CFSocketCopyAddress(sserver);
    //转换 sockaddr_in -> socketAddressActual
    struct sockaddr_in socketAddressActual;
    memcpy(&socketAddressActual, [sockerAddressActualData bytes], [sockerAddressActualData length]);
    self.port = ntohs(socketAddressActual.sin_port);
    printf("Socket listening on port %d \n",self.port);
    /* 创建一个 Run Loop Socket 源 */
    CFRunLoopSourceRef sourceRef = CFSocketCreateRunLoopSource(kCFAllocatorDefault, sserver, 0);
    /* Socket 源添加到Run Loop 中 */
    CFRunLoopAddSource(CFRunLoopGetCurrent(), sourceRef, kCFRunLoopCommonModes);
    CFRelease(sourceRef);
    return YES;
}

- (BOOL) publishServer {
    //创建服务器实例
    _service = [[NSNetService alloc]initWithDomain:@"local." type:@"_tonyipp._tcp" name:@"tony" port:self.port];
    //添加到服务到当前的Run Loop
    [_service scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSRunLoopCommonModes];
    [_service setDelegate:self];
    [_service publish];
    return YES;
}

#pragma mark - NSNetServiceDelegate
- (void)netServiceDidPublish:(NSNetService *)sender {
    NSLog(@"netServiceDidPublish");
    if ([@"tony" isEqualToString:sender.name]) {
        if (![sender getInputStream:&_inputStream outputStream:&_outputStream]) {
            NSLog(@"连接到服务器失败");
            return;
        }
    }
}


@end
