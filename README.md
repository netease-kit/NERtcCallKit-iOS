# NERtcCallKit-iOS

为了方便开发者接入音视频2.0呼叫功能，以组件的形式提供给客户，提高接入效率。[Demo传送门](https://github.com/netease-im/NIM_iOS_Demo/tree/NERtcCallKit)

## 功能开通

### 1. 登录

网易云控制台，点击【应用】>【创建】创建自己的App，在【功能管理】中申请开通如下功能

1. 若仅使用呼叫功能，则开通
   1. 【信令】
   2. 【音视频通话2.0】
   3. 【非安全模式】-组件默认使用非安全模式，开启安全模式请咨询SO
2. 若还需使用话单功能，则需要开通
   1. 【IM】
   2. 【G2话单功能】-目前仅支持联系销售/SO进行开通
      - 发送邮件至hzcaojiajun@corp.netease.com
      - 抄送hzsuzhongbin@corp.netease.com、hzliuxuanlin@corp.netease.com、wangjiangwen@corp.netease.com、zhangguanglu@corp.netease.com、hzyushaohua@corp.netease.com
      - 邮件内容：appkey、功能名称：G2话单消息通知

3. 在控制台中【appkey管理】获取appkey。

注：如果曾经已有相应的应用，可在原应用上申请开通【音视频通话2.0】及【信令】功能



## 整体架构图



![img](https://netease-we.feishu.cn/space/api/box/stream/download/asynccode/?code=e9f5e1dacd02782e23f257543f4e1cc3_8f118824ce50c961_boxcnK7D7XRErHIY9habMpiZHig_khhDdQLSWfkYrJbG7wCRKayms7i2Uy6V)



1. 下载Demo解压，进入NIMDemo，请点击NIM.xcworkspace进入工程
2. 找到组件为NERtcCallKit



### 集成方式

* cocoapods集成（推荐）

``` ruby
pod 'NERtcCallKit'
```



* 手动集成

> Demo中以Pod形式导入音视频 2.0 SDK，依赖于
>
> NERtcSDK 3.7.1 版本，
>
> NIMSDK 8.1.0  版本，
>
> NIMKIT 3.1.1 版本，
>
> 如有需要可自行升级

复制 NERtcCallKit 文件夹以及文件夹下的.h和.m文件，根据自己的工程需要，将他们复制到工程对应的路径下

### 组件结构

- NERtcCallKit 文件夹：音视频管理类，包含初始化，登录，呼叫，邀请等逻辑的相关操作管理
  - NERtcCallKit.h：封装层实现protocal NERtcCallKitDelegate封装实例方法
  - NERtcCallKitDelegateProxy.h：代理proxy的头文件（Demo业务层，可不关注）
  - NERtcCallOptions.h：组件推送配置
  - NERtcCallKitContext.h：存储用户信息相关（Demo业务层，可不关注）
  - NERtcCallKit+Private.h：组件封装私有的实例方法
  - NERtcCallKitConsts.h：定义类型的枚举
  - Consts 文件夹：定义NERtcCallKitErrors的头文件
  - Utils 文件夹：生成信令唯一标识requestID (Demo业务层，可不关注)
  - Status 文件夹
    - INERtcCallStatus.h：组件的接口
    - NERtcCallStatusIdleImpl.h：底层NERtc封装的实例方法
    - NERtcCallStatusCallingImpl.h：底层NERtc封装的实例方法
    - NERtcCallStatusCalledImpl.h：底层NERtc封装的实例方法
    - NERtcCallStatusInCallImpl.h：底层NERtc封装的实例方法



### 代码说明

#### 初始化

```objective-c
// 在AppDelegate中初始化
- (void)setupRTCKit {
    // 读取配置的appkey信息
   NSString *appKey = <#您的AppKey#>

   // 配置 NERtcCallOptions
    NERtcCallOptions *option = [NERtcCallOptions new];
    option.APNSCerName = yourCerName;

   // 初始化 组件
    [[NERtcCallKit sharedInstance] setupAppKey:appKey options:option];
}
```

#### 登录

> **组件与IM的login方法可共用，如果IM登录成功，组件可不在调用login方法**

```objective-c
// userID为云信的accid，token为云信的token
[[NERtcCallKit sharedInstance] login:userID token:token completion:^(NSError * _Nullable error) {

    //  根据登录回调处理业务

}];
```



#### Token注入

> // 安全模式音视频房间token获取，nil表示非安全模式. Block中一定要调用complete

> **@property** (**nonatomic**, **copy**, **nullable**) NERtcCallKitTokenHandler tokenHandler;

> 可参考在NTESAppDelegate.m的setupRTCKit方法中实现

```objective-c
// 注册获取token的服务
// 安全模式需要计算token，如果tokenHandler为nil表示非安全模式，需要联系经销商开通
 NERtcCallKit.sharedInstance.tokenHandler = ^(uint64_t uid, void (^complete)(NSString *token, NSError *error)) {

    // 下面获取token的逻辑建议替换成自己的，不建议从Demo服务器获取token
    [NTESRtcTokenUtils requestTokenWithUid:uid appKey:appKey completion:^(NSError * _Nullable error, NSString * _Nullable token) {

        complete(token, error);

    }];

 };
```

> 在线上环境中，token的获取需要放到您的应用服务端完成，然后由服务器通过安全通道把token传递给客户端。Demo中使用的URL仅仅是demoserver，不要在您的应用中使用。详细请参考: [获取安全模式token](https://dev.yunxin.163.com/docs/product/%E9%9F%B3%E8%A7%86%E9%A2%91%E9%80%9A%E8%AF%9D2.0/%E5%BF%AB%E9%80%9F%E5%85%A5%E9%97%A8/%E8%8E%B7%E5%8F%96Token )

#### 呼叫

> Demo中在 onTapMediaItemVideoChat 初始化 NECallViewController，及初始化 initWithOtherMember 传入userID，当前通话类型，可由开发者根据业务需求实现该controller。
>
> 目的是为了获取userID及通话类型。

```objective-c
// 组件封装的点对点呼叫方式
// self.otherUserID 为对方accid，type为NERtcCallType的枚举类型
[[NERtcCallKit sharedInstance] call:self.otherUserID type:self.type completion:^(NSError * _Nullable error) {
     //  根据登录回调处理业务

}];

```



#### 多人呼叫

```objective-c
/// 多人呼叫
/// @param userIDs  呼叫的用户ID数组
/// @param type 通话类型
/// @param completion 回调

 [[NERtcCallKit sharedInstance] groupCall:self.otherMembers type:NERtcCallTypeVideo completion:^(NSError * _Nullable error) {
     //  根据登录回调处理业务

}];
```



#### 监听

> 详情可参考组件中**NERtcCallKit.h**

```objective-c
/// 收到邀请的回调
/// @param invitor 邀请方
/// @param userIDs 房间中的被邀请的所有人（不包含邀请者）
/// @param isFromGroup 是否是群组
/// @param groupID 群组ID
/// @param type 通话类型
- (void)onInvited:(NSString *)invitor
          userIDs:(NSArray<NSString *> *)userIDs
      isFromGroup:(BOOL)isFromGroup
          groupID:(nullable NSString *)groupID
             type:(NERtcCallType)type;


/// 接受邀请的回调
/// @param userID 接受者
- (void)onUserEnter:(NSString *)userID;


/// 拒绝邀请的回调
/// @param userID 拒绝者
- (void)onUserReject:(NSString *)userID;


/// 取消邀请的回调
/// @param userID 邀请方
- (void)onUserCancel:(NSString *)userID;


/// 用户离开的回调
/// @param userID 用户userID
- (void)onUserLeave:(NSString *)userID;


/// 用户异常离开的回调
/// @param userID 用户userID
- (void)onUserDisconnect:(NSString *)userID;


/// 用户接受邀请的回调
/// @param userID 用户userID
- (void)onUserAccept:(NSString *)userID;


/// 忙线
/// @param userID 忙线的用户ID
- (void)onUserBusy:(NSString *)userID;


/// 通话结束
- (void)onCallEnd;


/// 呼叫超时
- (void)onCallingTimeOut;


/// 连接断开
/// @param reason 断开原因
- (void)onDisconnect:(NSError *)reason;


/// 发生错误
- (void)onError:(NSError *)error;


/// 启用/禁用相机
/// @param available 是否可用
/// @param userID 用户ID
- (void)onCameraAvailable:(BOOL)available userID:(NSString *)userID;


/// 启用/紧用麦克风
/// @param available 是否可用
/// @param userID 用户userID
- (void)onAudioAvailable:(BOOL)available userID:(NSString *)userID;


/// 网络状态监测回调
/// @param stats key为用户ID, value为对应网络状态
- (void)onUserNetworkQuality:(NSDictionary<NSString *, NERtcNetworkQualityStats *> *)stats;


/// 呼叫请求已被其他端接收的回调
- (void)onOtherClientAccept;


/// 呼叫请求已被其他端拒绝的回调
- (void)onOtherClientReject;
```



#### 接听

```objective-c
// 组件封装的接听方式
[[NERtcCallKit sharedInstance] accept:^(NSError * _Nullable error, NSArray<NSString *> * _Nullable joinedMembers) {
    //  根据登录回调处理业务
}];
```



#### 挂断

```objective-c
// 组件封装的挂断方式
[[NERtcCallKit sharedInstance] hangup:^(NSError * _Nullable error) {
    // 根据挂断完成操作的回调处理
}];
```



#### 话单

> **注：多人通话没有封装话单，如有需求，请自行实现。**

> 话单功能需要单独开通，如有需求，请联系对应商务。



1. 正常挂断，NIMRtcCallStatus 状态为 NIMRtcCallStatusComplete

> 调用组件封装的挂断之后，服务器会正常下发正常结束的话单。

客户端会通过客户端接收消息的回调onRecvMessages，收到一条类型为 **NIMMessageTypeRtcCallRecord**的消息，对消息解析并抛到上层进行展示，可参考

- - NIMRtcCallRecordObject.h，保存当前通话类型，频道ID，通话状态，及时长

- - NIMRtcCallRecordContentConfig.h，对消息进行封装

- - NIMSessionRtcCallRecordContentView.h，展示消息

2. 非正常挂断

> 异常挂断，需要业务层主动调用以下方式，组件话单提供给对方，包含**超时**、**忙线**、**拒绝**的话单都是组件内部发送的

```objective-c
// 取消通话
[[NERtcCallKit sharedInstance] cancel:^(NSError * _Nullable error) {
   // Do something
}];
```

底层实现主要是调用SDK发送点对点消息sendMessage，通过封装信息之后，发送到对方，对方收到消息解析。可参考NERtcCallKit中 **send1to1CallRecord** 方法

### UI相关

[Demo](https://github.com/netease-im/NIM_iOS_Demo/tree/NERtcCallKit)中UI可参考模块：

> 路径为：NIMDemo -> Classes -> Sections -> Session -> ViewController -> RTCVideoChat