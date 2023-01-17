@_exported import Manager

public protocol SipManagerDelegate: PSSipManagerDelegate {}

public struct SipManager {
    public weak var delegate: SipManagerDelegate?
    
    public var codecs: [PSCodecInfo] {
        PSSipManager.shared().codecs
    }
    
    public init() {
    }
    
    
    public func setupCall(domain: String, port: Int32, caller: String, user: String, pass: String) {
        PSSipManager.shared().setup(withDomain: domain,
                                    port: port,
                                    caller: caller,
                                    user: user,
                                    pass: pass)
        PSSipManager.shared().delegate = delegate
    }
    
    public func acceptIncomingCall() {
        PSSipManager.shared().acceptIncommingCall()
    }
    
    public func rejectIncomingCall() {
        PSSipManager.shared().rejectIncommingCall()
    }
    
    public func hangup() {
        PSSipManager.shared().hangup()
    }
    
    public func deactivation() {
        PSSipManager.shared().deactivation()
    }
}
