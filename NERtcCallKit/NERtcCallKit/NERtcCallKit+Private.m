//
//  NERtcCallKit+NERtcCallKit_Private.m
//  NERtcCallKit
//
//  Created by Wenchao Ding on 2021/3/31.
//  Copyright © 2021 Wenchao Ding. All rights reserved.
//

#import "NERtcCallKit+Private.h"
#import "NERtcCallKitContext.h"
#import "NERtcCallKitConsts.h"
#import "NERtcCallKitErrors.h"
#import "INERtcCallStatus.h"
#import "NERtcCallKitUtils.h"

@interface NERtcCallKit ()<INERtcCallStatus>

@end

@implementation NERtcCallKit (Private)

@dynamic delegateProxy, callStatus;

- (void)send1to1CallRecord:(NIMRtcCallStatus)callStatus
{
    if (self.context.isGroupCall) {
        return;
    }
    NSString *remoteUserID = self.context.inviteList.allValues.firstObject.accountId;
    NIMMessage *message = [[NIMMessage alloc] init];
    NIMSession *session = [NIMSession session:remoteUserID type:NIMSessionTypeP2P];
    NIMRtcCallRecordObject *record = [[NIMRtcCallRecordObject alloc] init];
    record.callStatus = callStatus;
    record.callType = self.context.channelInfo.channelType == NIMSignalingChannelTypeAudio ? NIMRtcCallTypeAudio : NIMRtcCallTypeVideo;
    record.channelID = self.context.channelInfo.channelId;
    message.messageObject = record;
    NSError *error;
    [NIMSDK.sharedSDK.chatManager sendMessage:message toSession:session error:&error];
    if (error) {
        [self.delegateProxy onError:error];
    }
}

- (void)signalingInvite:(NSString *)userID
                callees:(NSArray<NSString *> *)callees
            isFromGroup:(BOOL)isFromGroup
                groupID:(NSString *)groupID
             completion:(void (^)(NSError * _Nullable))completion {
    NIMSignalingInviteRequest *invite = [[NIMSignalingInviteRequest alloc] init];
    invite.accountId = userID;
    invite.requestId = [NERtcCallKitUtils generateRequestID];
    invite.channelId = self.context.channelInfo.channelId;
    invite.offlineEnabled = YES;
    
    NSString *callerUserID = self.context.userID;
    int64_t callerUid = self.context.localUid;
    
    NSMutableDictionary *dic = NSMutableDictionary.dictionary;
    dic[@"callType"] = @((NSInteger)isFromGroup);
    if (isFromGroup) {
        dic[@"callUserList"] = callees;
        if (groupID) {
            dic[@"groupID"] = groupID;
        }
    }
    NSString *channelName = [NSString stringWithFormat:@"%@|%@|%@", invite.channelId, @(isFromGroup), isFromGroup ? (groupID?:@"0") : @(callerUid)];
    dic[@"channelName"] = channelName;
    dic[@"version"] = self.class.versionCode;

    invite.customInfo = [NERtcCallKitUtils JSONStringWithObject:dic];
    
    NIMSignalingPushInfo *info = [[NIMSignalingPushInfo alloc] init];
    info.needPush = YES;
    NSString *appName = NSBundle.mainBundle.infoDictionary[@"CFBundleDisplayName"];
    info.pushTitle = appName;
    
    NIMSignalingChannelType channelType = self.context.channelInfo.channelType;
    NSString *typeString = channelType == NIMSignalingChannelTypeVideo ? @"视频" : @"语音";
    info.pushContent = [NSString stringWithFormat:@"%@邀请你%@通话",[NERtcCallKitUtils displayNameForUser:callerUserID groupID:groupID], typeString];
    NSMutableDictionary *muteDic = [NSMutableDictionary dictionary];
    if (callerUserID) {
        muteDic[@"userID"] = callerUserID;
    }
    info.pushPayload = [muteDic copy];
    invite.push = info;
    
    self.context.inviteList[invite.requestId] = invite;
    self.context.channelInfo.channelName = channelName;
    [NIMSDK.sharedSDK.signalManager signalingInvite:invite completion:^(NSError * _Nullable error) {
        if (error && (error.code == NIMRemoteErrorCodeSignalResPeerPushOffline || error.code == NIMRemoteErrorCodeSignalResPeerNIMOffline)) {
            error = nil;
        }
        if (completion) {
            completion(error);
        }
    }];
    
}

- (void)batchInvite:(NSArray<NSString *> *)userIDs
            groupID:(NSString *)groupID
         completion:(void (^)(NSError * _Nullable))completion {
    
    dispatch_group_t group = dispatch_group_create();
    __block NSError *outError = nil;
    
    NSMutableOrderedSet *callUsersOrderedSet = [NSMutableOrderedSet orderedSetWithArray:[self.context.allMembers valueForKeyPath:@"accountId"]];
    [callUsersOrderedSet addObjectsFromArray:[self.context.inviteList.allValues valueForKeyPath:@"accountId"]]; // 正在邀请中的加入
    [callUsersOrderedSet addObjectsFromArray:userIDs];
    [callUsersOrderedSet removeObject:self.context.userID];
    
    for (NSString *userID in userIDs) {
        
        dispatch_group_enter(group);
        [self signalingInvite:userID
                      callees:callUsersOrderedSet.array
                  isFromGroup:YES
                      groupID:groupID
                   completion:^(NSError * _Nullable error) {
            if (error) {
                outError = error;
            }
            dispatch_group_leave(group);
        }];
    }
    
    dispatch_group_notify(group, dispatch_get_main_queue(), ^{
        if (!outError) {
            if (completion) {
                completion(nil);
            }
        } else {
            if (completion) {
                NSError *error = outError ?: [NSError errorWithDomain:kNERtcCallKitErrorDomain code:kNERtcCallKitInviteError userInfo:@{NSLocalizedDescriptionKey: kNERtcCallKitInviteErrorDescription}];
                completion(error);
            }
        }
    });
}

- (void)cancelInvites:(void(^)(NSError * __nullable error))completion
{
    dispatch_group_t group = dispatch_group_create();
    NSArray<NIMSignalingInviteRequest *> *inviteRequests = self.context.inviteList.allValues;
    for (NIMSignalingInviteRequest *invite in inviteRequests) {
        NIMSignalingCancelInviteRequest *cancel = [[NIMSignalingCancelInviteRequest alloc] init];
        cancel.requestId = invite.requestId;
        cancel.accountId = invite.accountId;
        cancel.channelId = invite.channelId;
        cancel.offlineEnabled = invite.offlineEnabled;
        dispatch_group_enter(group);
        [NIMSDK.sharedSDK.signalManager signalingCancelInvite:cancel completion:^(NSError * _Nullable error) {
            if (error && error.code != NIMRemoteErrorCodeSignalResPeerPushOffline && error.code != NIMRemoteErrorCodeSignalResPeerNIMOffline) {
                [self.delegateProxy onError:error];
            }
            dispatch_group_leave(group);
        }];
    }
    dispatch_group_notify(group, dispatch_get_main_queue(), ^{
        if (completion) {
            completion(nil);
        }
    });
}

- (void)closeSignalChannel:(void (^)(void))completion
{
    if (!self.context.channelInfo) {
        if (self.callStatus != NERtcCallStatusIdle) { // 理论上不会走到这里
            self.callStatus = NERtcCallStatusIdle;
            NSLog(@"Error: channel has been cleared while calling status is %@", @(self.callStatus));
        }
        if (completion) {
            completion();
        }
        return;
    }
    NSLog(@"CK: Close signaling channel: %@", self.context.channelInfo.channelId);
    NIMSignalingCloseChannelRequest *close = [[NIMSignalingCloseChannelRequest alloc] init];
    close.channelId = self.context.channelInfo.channelId;
    [NIMSDK.sharedSDK.signalManager signalingCloseChannel:close completion:^(NSError * _Nullable error) {
        if (error) {
            [self.delegateProxy onError:error];
        }
        if (completion) {
            completion();
        }
    }];
    self.callStatus = NERtcCallStatusIdle;
    [NERtcEngine.sharedEngine leaveChannel];
    [self.context cleanUp];
}

- (void)fetchToken:(void (^)(NSString * _Nonnull, NSError * _Nullable))completion {
    if (!self.tokenHandler) {
        NSLog(@"CK: Using unsafe mode, return empty token");
        if (completion) {
            completion(@"", nil);
        }
        return;
    }
    NSString *channelId = self.context.channelInfo.channelId;
    uint64_t myUid = self.context.localUid;
    NSLog(@"CK: Request token for ChannelId: %@, myUid: %@", channelId, @(myUid));
    __weak typeof(self) wself = self;
    self.tokenHandler(self.context.localUid, ^(NSString *token, NSError *error) {
        __strong typeof(wself) sself = wself;
        if (!sself) return;
        NSLog(@"CK: Request token for channel result:%@ for ChannelId: %@, myUid: %@", error.localizedDescription?:token, channelId, @(myUid));
        sself.context.token = token;
        [sself.context.tokenLock signal];
        [sself.context.tokenLock unlock];
        if (completion) {
            completion(token, error);
        }
    });
}

- (void)waitTokenTimeout:(NSTimeInterval)timeout completion:(void(^)(NSString *token))completion {
    if (!self.tokenHandler) {
        return completion(@"");
    }
    if (self.context.token.length) {
        return completion(self.context.token);
    }
    __weak typeof(self) wself = self;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        __strong typeof(wself) sself = wself;
        if (!sself) return;
        if (sself.context.token.length) {
            return completion(sself.context.token);
        }
        [sself.context.tokenLock waitUntilDate: [NSDate dateWithTimeIntervalSinceNow:timeout]];
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(sself.context.token);
        });
    });
}

- (void)joinRtcChannel:(NSString *)channelID
                 myUid:(uint64_t)myUid
            completion:(void (^)(NSError * _Nullable))completion {
    if (!self.tokenHandler) {
        [self joinRtcChannel:channelID myUid:myUid token:@"" completion:completion];
        return;
    }
    __weak typeof(self) wself = self;
    [self fetchToken:^(NSString * _Nonnull token, NSError * _Nullable error) {
        __strong typeof(wself) sself = wself;
        [sself joinRtcChannel:channelID myUid:myUid token:token completion:completion];
    }];
}

- (void)joinRtcChannel:(NSString *)channelID
                 myUid:(uint64_t)myUid
                 token:(NSString *)token
            completion:(void(^)(NSError * _Nullable error))completion {
    
    if (!self.context.channelInfo) {
        if (completion) {
            NSError *error = [NSError errorWithDomain:kNERtcCallKitErrorDomain code:kNERtcCallKitChannelIsClosedError userInfo:@{NSLocalizedDescriptionKey: kNERtcCallKitChannelIsClosedErrorDescription}];
            completion(error);
        }
        return;
    }
    if (!token) {
        return NSLog(@"CK: Cannot Join RTC with a nil token!!");
    }
    NSLog(@"CK:  Join RTC Channel: %@, uid : %lld, token: %@", channelID, myUid, token);
    
    BOOL videoEnable = self.context.channelInfo.channelType == NIMSignalingChannelTypeVideo;
    [NERtcEngine.sharedEngine enableLocalVideo:videoEnable];
    int ret = [NERtcEngine.sharedEngine joinChannelWithToken:token
                                                 channelName:channelID
                                                       myUid:myUid
                                                  completion:^(NSError * _Nullable error, uint64_t channelId, uint64_t elapesd) {
        NSLog(@"CK: Join RTC finish with cid: %@, error: %@", @(channelId), error.localizedDescription);
        if (completion) {
            completion(error);
        }
    }];
    if (ret == kNERtcErrInvalidState) {
        NSError *error = [NSError errorWithDomain:kNERtcCallKitErrorDomain code:kNERtcErrInvalidState userInfo:@{NSLocalizedDescriptionKey: NERtcErrorDescription(kNERtcErrInvalidState)}];
        completion(error);
    }
}

- (void)waitTimeout {
    [self cancelTimeout];
    [self performSelector:@selector(onTimeout) withObject:self afterDelay:self.timeOutSeconds];
}

- (void)cancelTimeout {
    [NSObject cancelPreviousPerformRequestsWithTarget:self];
}

@end
