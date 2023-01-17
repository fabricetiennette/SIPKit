#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdocumentation"
#import "PSSipManager.h"
#import <pjsua-lib/pjsua.h>
#import <AVFoundation/AVFoundation.h>
#pragma clang diagnostic pop

char * const ThisFile = "PSSipManager";

// Pointer for calling Obj-C methods from inside C/C++ functions
id selfRef;

@interface PSSipManager () {
    pj_status_t status;
    pjsua_acc_id acc_id;
    pjsua_config cfg;
    pjsua_logging_config log_cfg;
    pjsua_transport_config transport_cfg;
    pjsua_acc_config acc_cfg;
    pjsua_acc_info acc_info;
    pjsua_call_info call_info;
    pjsua_call_id call_id;
}

@property (atomic) BOOL isInited;
@property (atomic) BOOL isAddedAccount;
@property (atomic) BOOL isEnabledSound;

@property (nonatomic, copy) NSArray<PSCodecInfo *> *codecs;

@property (strong, nonatomic) NSTimer *statusTimer;

@end

@implementation PSSipManager

+ (PSSipManager *)shared {
    static PSSipManager *singleton;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        singleton = [[PSSipManager alloc] init];
    });
    return singleton;
}

- (id)init {
    if (self = [super init]) {
        selfRef = self;
    }
    return self;
}

- (void)onErrorWithDescription:(NSString *)description status:(pj_status_t)status {
    pjsua_perror(ThisFile, description.UTF8String, status);
    pjsua_destroy();
}

- (void)setupWithDomain:(NSString *)domain
                   port:(int)port
                 caller:(NSString *)caller
                   user:(NSString *)user
                   pass:(NSString *)pass
{
    [self deactivation];
    
    NSCharacterSet *set = [NSCharacterSet URLFragmentAllowedCharacterSet];
    NSString *callerURL = [[NSString stringWithFormat:@"sip:%@@%@", user, domain] stringByAddingPercentEncodingWithAllowedCharacters:set];
    
    //Creating pjsua
    status = pjsua_create();
    if (status != PJ_SUCCESS) {
        [self onErrorWithDescription:@"Error in pjsua_create(): " status:status];
        return;
    }
    
    //Verifing the url
    status = pjsua_verify_url(callerURL.UTF8String);
    if (status != PJ_SUCCESS) {
        [self onErrorWithDescription:@"Invalid URL: " status:status];
        return;
    }
    
    //Initializing pjsua
    {
        pjsua_config cfg;
        pjsua_logging_config log_cfg;
        
        pjsua_config_default(&cfg);
        cfg.cb.on_incoming_call = &on_incoming_call;
        cfg.cb.on_call_media_state = &on_call_media_state;
        cfg.cb.on_call_state = &on_call_state;
        cfg.cb.on_reg_state = &on_reg_state;
        
        pjsua_logging_config_default(&log_cfg);
//        log_cfg.console_level = 2;
        log_cfg.console_level = 4;
        log_cfg.level = 5;
        
        status = pjsua_init(&cfg, &log_cfg, NULL);
        if (status != PJ_SUCCESS) {
            [self onErrorWithDescription:@"Error in pjsua_init(): " status:status];
            return;
        }
    }
    self.isInited = YES;
    
    //Adding UDP transport
    {
        pjsua_transport_config cfg;
        pjsua_transport_config_default(&cfg);
        
        // UDP port number to bind locally. This setting MUST be specified
        // even when default port is desired. If the value is zero, the
        // transport will be bound to any available port, and application
        // can query the port by querying the transport info.
        cfg.port = 0;

        status = pjsua_transport_create(PJSIP_TRANSPORT_UDP, &cfg, NULL);
        if (status != PJ_SUCCESS) [self onErrorWithDescription:@"Error creating transport" status:status];
    }
    status = pjsua_start();
    if (status != PJ_SUCCESS) [self onErrorWithDescription:@"Error starting pjsua" status:status];
    
    //Register to SIP server by creating SIP account
    {
        pjsua_acc_config cfg;
        
        pjsua_acc_config_default(&cfg);
        NSString *userURL = [NSString stringWithFormat:@"sip:%@@%@", user, domain];
        cfg.id = pj_str((char *)(userURL.UTF8String));
        
        NSString *regURL = [NSString stringWithFormat:@"sip:%@", domain];
        cfg.reg_uri = pj_str((char *)(regURL.UTF8String));
        cfg.cred_count = 1;
        cfg.cred_info[0].realm = pj_str((char*)"*");
        cfg.cred_info[0].scheme = pj_str((char*)"digest");
        cfg.cred_info[0].username = pj_str((char*)user.UTF8String);
        cfg.cred_info[0].data_type = PJSIP_CRED_DATA_PLAIN_PASSWD;
        cfg.cred_info[0].data = pj_str((char*)pass.UTF8String);
        
        status = pjsua_acc_add(&cfg, PJ_TRUE, &acc_id);
        if (status != PJ_SUCCESS) {
            [self onErrorWithDescription:@"Error adding account" status:status];
            return;
        }
        
        self.isAddedAccount = YES;
        self.codecs = [self arrayOfAvailableCodecs];
        [self.delegate didRegisterToSipServerWithSuccess];
    }
}

- (void)deactivation {
    if (self.isInited) {
        if (call_info.media_status == PJSUA_CALL_MEDIA_ACTIVE) {
            // on deactivation, if call media is active we disable it
            NSLog(@"%s - %d\nstatus = %d", __PRETTY_FUNCTION__, __LINE__, call_info.media_status);
            [self disableSound];
        }
        
        if (self.isAddedAccount) {
            status = pjsua_acc_del(acc_id);
            if (status != PJ_SUCCESS) [self onErrorWithDescription:@"Error account deletting" status:status];
        }
        
        status = pjsua_destroy();
        if (status != PJ_SUCCESS) [self onErrorWithDescription:@"Error destroying" status:status];
        
        self.isAddedAccount = NO;
        self.isInited = NO;
    }
}

- (void)startObserver:(id<PSSipManagerDelegate>)delegate {
    self.delegate = delegate;
}

#pragma mark - Actions

- (void)acceptIncommingCall {
    pjsua_call_answer(call_id, 200, NULL, NULL);
}

- (void)rejectIncommingCall {
    pjsua_call_answer(call_id, PJSIP_SC_DECLINE, NULL, NULL);
}

- (void)hangup {
    pjsua_call_hangup_all();
}

- (NSArray *)arrayOfAvailableCodecs {
    NSMutableArray *arr = [[NSMutableArray alloc] init];
    
    unsigned int count = 255;
    pjsua_codec_info codecs[count];
    pjsua_enum_codecs(codecs, &count);
    
    for (int i = 0; i < count; i++) {
        pjsua_codec_info pjCodec = codecs[i];
        PSCodecInfo *codec = [[PSCodecInfo alloc] initWithCodecInfo:&pjCodec];
        [arr addObject:codec];
    }
    return [NSArray arrayWithArray:arr];
}

#pragma mark - Notifications

/* Obj-C method that implements logic for on_incoming_call(pjsua_acc_id, pjsua_call_id, pjsip_rx_data) */
- (void)onIncommingCallAccId:(pjsua_acc_id)accId callId:(pjsua_call_id)callId rxData:(pjsip_rx_data *)rdata {
    // Assign parameter values to static variables
    acc_id = accId;
    call_id = callId;
    
    // Update call_info variable
    status = pjsua_call_get_info(call_id, &call_info);
    if(status != PJ_SUCCESS) {
        NSLog(@"%s - %d\nstatus = %d", __PRETTY_FUNCTION__, __LINE__, status);
    }
    
    //PJ_LOG(3,(FILE, "Incoming call from %.*s!!", (int)call_info.remote_info.slen, call_info.remote_info.ptr));
    
    [self.delegate didReceivedIncommingCall];
}

/* Obj-C method that implements logic for on_incoming_call() callback */
- (void)onCallStateCallId:(pjsua_call_id)callId event:(pjsip_event *)e {
    // Assign parameter values to static variables
    call_id = callId;
    
    // Update call_info variable
    status = pjsua_call_get_info(call_id, &call_info);
    if(status != PJ_SUCCESS) {
        NSLog(@"%s - %d\nstatus = %d", __PRETTY_FUNCTION__, __LINE__, status);
    }
    
    if (call_info.state == PJSIP_INV_STATE_CONNECTING) {
        [self.delegate callWasConnecting];
    }

    if(call_info.state == PJSIP_INV_STATE_CALLING){
        [self.delegate callWasStillCalling];
    }
    
    if(call_info.state == PJSIP_INV_STATE_CONFIRMED){
        [self.delegate callWasEstabilished];
    }
    
    if(call_info.state == PJSIP_INV_STATE_DISCONNECTED){
        if (call_info.last_status == PJSIP_SC_NOT_FOUND || call_info.last_status == PJSIP_SC_BAD_EXTENSION) {
            [self.delegate callWasDisconnectedUnregisteredPeer];
        }
        else if (call_info.last_status == PJSIP_SC_TEMPORARILY_UNAVAILABLE){
            [self.delegate callWasDisconnectedPeerTemporarilyUnavailable];
            if(call_info.connect_duration.sec == 0){
                [self.delegate callWillTryAgain];
            }
        }
        else if (call_info.last_status == PJSIP_SC_BAD_GATEWAY){
            [self.delegate callWasDisconnectedBadGateway];
        }
        else if (call_info.last_status == PJSIP_SC_BUSY_HERE){
            [self.delegate callWasDisconnectedPeerBusy];
        }
        else{
            [self.delegate callWasDisconnected];
        }
    }
}

- (void)enableSound {
    pjsua_conf_connect(call_info.conf_slot, 0);
    pjsua_conf_connect(0, call_info.conf_slot);
    self.isEnabledSound = YES;
}

- (void)disableSound {
    pjsua_conf_disconnect(call_info.conf_slot, 0);
    pjsua_conf_disconnect(0, call_info.conf_slot);
    self.isEnabledSound = NO;
}

- (void)onCallMediaState:(pjsua_call_id)callId {
    // Assign parameter values to static variables
    call_id = callId;
    
    // Update call_info variable
    status = pjsua_call_get_info(callId, &call_info);
    
    if (call_info.media_status == PJSUA_CALL_MEDIA_ACTIVE) {
        //When media is active, connecting call to sound device.
        [self enableSound];
    }
    
    if(status != PJ_SUCCESS) {
        NSLog(@"%s - %d\nstatus = %d", __PRETTY_FUNCTION__, __LINE__, status);
    }
}

- (void)onRegState:(pjsua_acc_id)accId {
    acc_id = accId;
    status = pjsua_acc_get_info(acc_id, &acc_info);
    if(status != PJ_SUCCESS) {
        NSLog(@"%s - %d @pjsua_acc_get_info(acc_id, &acc_info)\nstatus = %d", __PRETTY_FUNCTION__, __LINE__, status);
        // TODO: handle error
        return;
    }
    
    if(acc_info.status != PJSIP_SC_OK && acc_info.status != PJSIP_SC_ACCEPTED) {
        // TODO: handle status
        return;
    }
}


#pragma mark - C functions
static void on_reg_state(pjsua_acc_id acc_id) {
    [selfRef onRegState:acc_id];
}

/* Callback called by the library upon receiving incoming call */
static void on_incoming_call(pjsua_acc_id acc_id, pjsua_call_id call_id, pjsip_rx_data *rdata) {
    [selfRef onIncommingCallAccId:acc_id callId:call_id rxData:rdata];
}

/* Callback called by the library when call's state has changed */
static void on_call_state(pjsua_call_id call_id, pjsip_event *e) {
    [selfRef onCallStateCallId:call_id event:e];
}

/* Callback called by the library when call's media state has changed */
static void on_call_media_state(pjsua_call_id call_id) {
    [selfRef onCallMediaState:call_id];
}

@end


