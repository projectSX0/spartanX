
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

public protocol SXSocket {
    var sockfd: Int32 { get set }
    
    var domain: SXSocketDomains { get set }
    var type: SXSocketTypes { get set }
    var `protocol`: Int32 { get set }
    
    var bufsize: Int { get set }
    
    var port: in_port_t? { get set }
    var address: SXSocketAddress? { get set }
}

public struct SXLocalSocket : SXSocket, SXLocal {
    public var sockfd: Int32
    
    public var domain: SXSocketDomains
    public var type: SXSocketTypes
    public var `protocol`: Int32
    
    public var bufsize: Int
    
    public var port: in_port_t?
    public var address: SXSocketAddress?
    
    public init(port: in_port_t,
                domain: SXSocketDomains,
                type: SXSocketTypes,
                protocol: Int32 = 0,
                bufsize: Int) throws {
        
        self.address = try SXSocketAddress(withDomain: domain, port: port)
        self.port = port
        self.domain = domain
        self.`protocol` = `protocol`
        self.bufsize = bufsize
        self.type = type
        self.sockfd = socket(Int32(domain.rawValue), type.rawValue, `protocol`)
        if self.sockfd == -1 {throw SXSocketError.socket(String.errno)}
        
    }
    
    public init(addr: SXSocketAddress,
                port: in_port_t,
                type: SXSocketTypes,
                `protocol`: Int32,
                bufsize: Int) throws {
        
        self.address = addr
        switch addr {
        case .INET:
            self.domain = .INET
        case .INET6:
            self.domain = .INET6
        case .UNIX:
            self.domain = .UNIX
        }
        self.port = port
        self.`protocol` = `protocol`
        self.bufsize = bufsize
        self.type = type
        self.sockfd = socket(Int32(domain.rawValue), type.rawValue, `protocol`)
        if self.sockfd == -1 {throw SXSocketError.socket(String.errno)}
    }
}

public struct SXRemoteSocket : SXSocket, SXRemote {
    public var sockfd: Int32
    
    public var domain: SXSocketDomains
    public var type: SXSocketTypes
    public var `protocol`: Int32
    
    public var bufsize: Int
    public var port: in_port_t?
    public var address: SXSocketAddress?
    
    public init(fd: Int32,
                domain: SXSocketDomains,
                type: SXSocketTypes,
                `protocol`: Int32,
                bufsize: Int = 16384) throws {
        
        var caddr = sockaddr()
        var len = socklen_t()
        getsockname(fd, &caddr, &len)
        
        self.address = try SXSocketAddress(caddr, socklen: len)
        self.sockfd = fd
        self.domain = domain
        self.type = type
        self.`protocol` = `protocol`
        self.bufsize = bufsize
        var yes = 1
        setsockopt(sockfd, SOL_SOCKET, SO_NOSIGPIPE, &yes, UInt32(sizeof(Int32.self)))
    }
    
    public init(fd: Int32,
                addr: sockaddr,
                len: socklen_t,
                type: SXSocketTypes,
                `protocol`: Int32,
                bufsize: Int = 16384) throws {
        self.address = try SXSocketAddress(addr, socklen: len)
        self.sockfd = fd
        
        switch Int(len) {
        case sizeof(sockaddr_in.self):
            self.domain = .INET
        case sizeof(sockaddr_in6.self):
            self.domain = .INET6
        case sizeof(sockaddr_un.self):
            self.domain = .UNIX
        default:
            throw SXSocketError.socket("Unknown domain")
        }
        
        self.type = type
        self.`protocol` = `protocol`
        self.bufsize = bufsize
    }
}

public protocol SXLocal {
    
}

public protocol SXRemote {
    
}

