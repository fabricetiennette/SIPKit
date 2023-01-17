#import <Foundation/Foundation.h>
#import "PSCodecInfo.h"

@protocol PSSipManagerDelegate<NSObject>

- (void)didRegisterToSipServerWithSuccess;
- (void)didReceivedIncommingCall;
- (void)callWasConnecting;
- (void)callWasDisconnected;
- (void)callWasDisconnectedUnregisteredPeer;
- (void)callWillTryAgain;
- (void)callWasDisconnectedPeerTemporarilyUnavailable;
- (void)callWasDisconnectedBadGateway;
- (void)callWasDisconnectedPeerBusy;
- (void)callWasEstabilished;
- (void)callWasStillCalling;

@end

@interface PSSipManager : NSObject

@property (nonatomic, weak) id<PSSipManagerDelegate> delegate;
@property (nonatomic, readonly) NSArray<PSCodecInfo *> *codecs;

+ (PSSipManager *)shared;
- (void)startObserver:(id<PSSipManagerDelegate>)delegate;
- (void)deactivation;

- (void)setupWithDomain:(NSString *)domain
                   port:(int)port
                 caller:(NSString *)caller
                   user:(NSString *)user
                   pass:(NSString *)pass;


- (void)acceptIncommingCall;
- (void)rejectIncommingCall;
- (void)hangup;

@end
