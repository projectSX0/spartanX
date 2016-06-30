
//  Copyright (c) 2016, Yuji
//  All rights reserved.
//
//  Redistribution and use in source and binary forms, with or without
//  modification, are permitted provided that the following conditions are met:
//
//  1. Redistributions of source code must retain the above copyright notice, this
//  list of conditions and the following disclaimer.
//  2. Redistributions in binary form must reproduce the above copyright notice,
//  this list of conditions and the following disclaimer in the documentation
//  and/or other materials provided with the distribution.
//
//  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
//  ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
//  WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
//  DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR
//  ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
//  (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
//  LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
//  ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
//  (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
//  SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
//
//  The views and conclusions contained in the software and documentation are those
//  of the authors and should not be interpreted as representing official policies,
//  either expressed or implied, of the FreeBSD Project.
//
//  Created by Yuji on 6/3/16.
//  Copyright © 2016 yuuji. All rights reserved.
//

import Foundation
import Darwin

protocol SXClient : SXLocalSocket, SXRuntimeController, SXRuntimeObject {

}

public class SXStreamClient: SXClient, SXStreamProtocol {
    
    /* SXLocalSocket */
    public var sockfd: Int32
    public var domain: SXSocketDomains
    public var type: SXSocketTypes
    public var `protocol`: Int32
    public var port: in_port_t?
    public var bufsize: Int
    
    /* SXRuntimeController */
    public var method: SXRuntimeDataMethods
    public var recvFlag: Int32 = 0
    public var sendFlag: Int32 = 0
    
    /* SXRuntimeObject */
    public var owner: SXRuntimeObject?
    public var status: SXStatus = .IDLE
    
    public func statusDidChange(status status: SXStatus) {
        self.delegate?.objectDidChangeStatus(object: self, status: status)
    }

    /* SXStreamProtocol */
    public var addr: SXSockaddr? /* target */
    public var delegate: SXRuntimeObjectDelegate?

    public init(hostname: String, service: String, protocol: Int32 = 0, bufsize: Int = 16384,handler: ((object: SXRuntimeObject, data: Data) -> Bool)) throws {
        self.method = .block(SXRuntimeDataHandlerBlocks(didReceiveDataHandler: handler, didReceiveErrorHandler: nil))
        guard let addr = try SXSockaddr.DNSLookup(hostname: hostname, service: service) else {throw SXAddrError.unknownDomain}
        guard let domain = addr.resolveDomain() else {throw SXAddrError.unknownDomain }

        self.addr = addr /* SXStreamProtocol */
        
        /* SXLocalSocket */
        self.domain = domain
        self.type = SXSocketTypes.SOCK_STREAM
        self.`protocol` = `protocol`
        
        self.port = 0
        self.bufsize = bufsize
        
        self.sockfd = socket(Int32(domain.rawValue), type.rawValue, `protocol`)
        if self.sockfd == -1 {throw SXSocketError.socket(String.errno)}
    }

    public init(ip: String, port: in_port_t, domain: SXSocketDomains, `protocol`: Int32 = 0, bufsize: Int = 16384, handler: ((object: SXRuntimeObject, data: Data) -> Bool)) throws {
        self.method = .block(SXRuntimeDataHandlerBlocks(didReceiveDataHandler: handler, didReceiveErrorHandler: nil))
        guard let addr = SXSockaddr(address: ip, withDomain: domain, port: port) else {throw SXAddrError.unknownDomain}
        self.addr = addr;
        self.port = 0
        self.domain = domain
        self.`protocol` = `protocol`
        self.bufsize = bufsize
        self.type = SXSocketTypes.SOCK_STREAM
        self.sockfd = socket(Int32(domain.rawValue), type.rawValue, `protocol`)
        if self.sockfd == -1 {throw SXSocketError.socket(String.errno)}
    }

    public init(hostname: String, service: String, protocol: Int32 = 0, bufsize: Int = 16384, delegate: SXRuntimeDataDelegate) throws {
        self.method = .delegate(delegate)
        guard let addr = try SXSockaddr.DNSLookup(hostname: hostname, service: service) else {throw SXAddrError.unknownDomain}
        guard let domain = addr.resolveDomain() else {throw SXAddrError.unknownDomain }
        self.addr = addr;
        self.port = 0
        self.domain = domain
        self.`protocol` = `protocol`
        self.bufsize = bufsize
        self.type = SXSocketTypes.SOCK_STREAM
        self.sockfd = socket(Int32(domain.rawValue), type.rawValue, `protocol`)
        if self.sockfd == -1 {throw SXSocketError.socket(String.errno)}
    }

    public init(ip: String, port: in_port_t, domain: SXSocketDomains, `protocol`: Int32 = 0, bufsize: Int = 16384, delegate: SXRuntimeDataDelegate) throws {
        self.method = .delegate(delegate)
        guard let addr = SXSockaddr(address: ip, withDomain: domain, port: port) else {throw SXAddrError.unknownDomain}
        self.addr = addr;
        self.port = 0
        self.domain = domain
        self.`protocol` = `protocol`
        self.bufsize = bufsize
        self.type = SXSocketTypes.SOCK_STREAM
        self.sockfd = socket(Int32(domain.rawValue), type.rawValue, `protocol`)
        if self.sockfd == -1 {throw SXSocketError.socket(String.errno)}
    }

    #if swift(>=3)
    public func start(_ queue: DispatchQueue, initialPayload: Data?) {
        do {
            try self.connect()
            
            
            if let payload = initialPayload {
                self.send(data: payload, flags: 0)
            }
            
            var s = 0
            var suspended = false
            self.status = .RUNNING

            queue.async() {
                repeat {
                    if let owner = self.owner {
                        if owner.status != .RUNNING {
                            self.status = owner.status
                        }
                    }
                    
                    func handleData() {
                        do {
                            let data = try self.receive(size: self.bufsize, flags: 0)
                            let proceed = self.method.didReceiveData(object: self, data: data)
                            s = proceed ? data.length : 0
                        } catch {
                            self.method.didReceiveError(object: self, err: error)
                            s = 0
                        }
                    }
                    
                    switch self.status {
                    case .RUNNING:
                        handleData()
                        
                    case .RESUMMING:
                        self.status = .RUNNING
                        self.statusDidChange(status: self.status)
                        
                    case .SUSPENDED:
                        if !suspended {
                            self.statusDidChange(status: self.status)
                        }
                        suspended = true
                        
                        let data = try? self.receive(size: self.bufsize, flags: 0)
                        if (data == nil || data?.length == 0 || data?.length == -1) { s = 0 }
                        
                        switch self.status {
                        case .SHOULD_TERMINATE, .IDLE:
                            s = 0
                        case .RUNNING, .RESUMMING:
                            handleData()
                        default: break
                        }
                    case .SHOULD_TERMINATE, .IDLE:
                        self.statusDidChange(status: self.status)
                    }
                } while (s > 0)
                _ = self.close()
            }
        } catch {
            self.method.didReceiveError(object: self, err: error)
        }
    }
    #else
    public func start(queue: dispatch_queue_t, initialPayload: Data?) {
        do {
            try self.connect()


            if let payload = initialPayload {
                self.send(data: payload, flags: 0)
            }

            var s = 0
            var suspended = false
            self.status = .RUNNING
            dispatch_async(queue, {
                repeat {
                    if let owner = self.owner {
                        if owner.status != .RUNNING {
                            self.status = owner.status
                        }
                    }

                    func handleData() {
                        do {
                            let data = try self.receive(size: self.bufsize, flags: 0)
                            let proceed = self.method.didReceiveData(object: self, data: data)
                            s = proceed ? data.length : 0
                        } catch {
                            self.method.didReceiveError(object: self, err: error)
                            s = 0
                        }
                    }

                    switch self.status {
                    case .RUNNING:
                        handleData()

                    case .RESUMMING:
                        self.status = .RUNNING
                        self.statusDidChange(status: self.status)

                    case .SUSPENDED:
                        if !suspended {
                            self.statusDidChange(status: self.status)
                        }
                        suspended = true

                        let data = try? self.receive(size: self.bufsize, flags: 0)
                        if (data == nil || data?.length == 0 || data?.length == -1) { s = 0 }

                        switch self.status {
                        case .SHOULD_TERMINATE, .IDLE:
                            s = 0
                        case .RUNNING, .RESUMMING:
                            handleData()
                        default: break
                        }
                    case .SHOULD_TERMINATE, .IDLE:
                        self.statusDidChange(status: self.status)
                    }
                } while (s > 0)
                self.close()
            })
        } catch {
            self.method.didReceiveError(object: self, err: error)
        }
    }
    #endif
    
    public func close() -> Int32 {
        self.owner = nil
        return Darwin.close(self.sockfd)
    }
}
