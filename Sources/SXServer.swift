
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
//  Created by yuuji on 6/2/16.
//  Copyright © 2016 yuuji. All rights reserved.
//

import Foundation
import FoundationPlus

open class SXServerSocket : ServerSocket, KqueueManagable {
    
    public var hashValue: Int
    
    public var address: SXSocketAddress?
    public var port: in_port_t?
    
    public var sockfd: Int32
    public var domain: SocketDomains
    public var type: SocketTypes
    public var `protocol`: Int32
    
    open var backlog: Int
    open var service: SXService
    
    internal var _accept: (_ from: SXServerSocket) throws -> ClientSocket
    
    public init(service: SXService,
                type: SocketTypes,
                conf: SXSocketConfiguation,
                accept: @escaping (_ from: SXServerSocket) throws -> ClientSocket) throws {
        
        self.service = service
        self.type = type
        self.address = conf.address
        self.`protocol` = conf.`protocol`
        self.domain = conf.domain
        self.backlog = conf.backlog
        self._accept = accept
        
        self.sockfd = socket(Int32(domain.rawValue), type.rawValue, `protocol`)
        
        if sockfd == -1 {
            throw SocketError.socket(String.errno)
        }
        
        self.hashValue = Int(self.sockfd) * time(nil)
        
        if self.type == .stream {
            try self.bind()
            try self.listen()
        }
    }
    
    public static func tcpIpv4(service: SXStreamService, port: in_port_t, backlog: Int = 50) throws  -> SXServerSocket {
        
        let conf = SXSocketConfiguation(domain: .inet, type: .stream, port: port, backlog: backlog, using: 0)
        let fns = SXClientSocket.standardIOHandlers
        return try SXServerSocket(service: service, type: .stream, conf: conf) {
                        (server: SXServerSocket) throws -> SXClientSocket in
        
                        var addr = sockaddr()
                        var socklen = socklen_t()
                        let fd = Foundation.accept(server.sockfd, &addr, &socklen)
                        getpeername(fd, &addr, &socklen)
                        var client = try! SXClientSocket(fd: fd,
                                                         addrinfo: (addr: addr, len: socklen),
                                                         sockinfo: (type: conf.type, protocol: conf.`protocol`),
                                                         functions: fns)
                        return client
                    }
    }
    
    public static func tcpIpv6(service: SXStreamService, port: in_port_t, backlog: Int = 50) throws  -> SXServerSocket {
        
        let conf = SXSocketConfiguation(domain: .inet6, type: .stream, port: port, backlog: backlog, using: 0)
        let fns = SXClientSocket.standardIOHandlers
        return try SXServerSocket(service: service, type: .stream, conf: conf) {
            (server: SXServerSocket) throws -> SXClientSocket in
            
            var addr = sockaddr()
            var socklen = socklen_t()
            let fd = Foundation.accept(server.sockfd, &addr, &socklen)
            getpeername(fd, &addr, &socklen)
            var client = try! SXClientSocket(fd: fd,
                                             addrinfo: (addr: addr, len: socklen),
                                             sockinfo: (type: conf.type, protocol: conf.`protocol`),
                                             functions: fns)
            return client
        }
    }
    
    public static func unix(service: SXService, domain: String, type: SocketTypes, backlog: Int = 50) throws -> SXServerSocket {
        let conf = SXSocketConfiguation(unixDomain: domain, type: type, backlog: backlog, using: 0)
        let fns = SXClientSocket.standardIOHandlers
        
        return try SXServerSocket(service: service, type: type, conf: conf) {
            (server: SXServerSocket) throws -> SXClientSocket in
            
            var addr = sockaddr()
            var socklen = socklen_t()
            let fd = Foundation.accept(server.sockfd, &addr, &socklen)
            getpeername(fd, &addr, &socklen)
            #if os(Linux)
                socklen = 110 /* linux getpeername bug */
            #endif
            let client = try! SXClientSocket(fd: fd,
                                             addrinfo: (addr: addr, len: socklen),
                                             sockinfo: (type: conf.type, protocol: conf.`protocol`),
                                             functions: fns)
            return client
        }
        
    }
}

//MARK: Runtime
public extension SXServerSocket {
    public func listen() throws {
        if Foundation.listen(sockfd, Int32(self.backlog)) < 0 {
            throw SocketError.listen(String.errno)
        }
    }
    
    public func accept() throws -> ClientSocket {
        return try self._accept(self)
    }
    
    public func runloop(manager: SXKernel, _ ev: event) {
        do {
            if self.type == .stream {
                let client = try self.accept()
                let queue = try SXQueue(fd: client.sockfd, readFrom: client, writeTo: client, with: self.service)
                if let service = service as? SXStreamService {
                    if let client = client as? SXClientSocket {
                        try service.accepted(socket: client, as: queue)
                    }
                }
            }
        } catch {
            //FIXME: use real handler
            print(error)
        }
        
        #if os(FreeBSD) || os(OSX) || os(iOS) || os(watchOS) || os(tvOS) || os(PS4)
            manager.thread.exec {
                manager.register(self)
            }
        #endif
    }
    
    public func done() {
        close(self.sockfd)
    }
    
    private func listenloop() throws {
        try self.listen()
    }
}

public extension SXServerSocket {

}
