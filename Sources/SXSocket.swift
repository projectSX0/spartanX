
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

import Darwin
import Foundation

public protocol SXSocket {
    var sockfd: Int32 {get set}
    var type: SXSocketTypes {get set}
    var bufsize: Int {get set}
}

extension SXSocket {
    public func close() {
        _ = Darwin.close(self.sockfd)
    }
}

public protocol SXLocalSocket : SXSocket {
    
    /* SXSocket */
    var sockfd: Int32 {get set}
    var type: SXSocketTypes {get set}
    var bufsize: Int {get set}
    
    var domain: SXSocketDomains {get set}
    var `protocol`: Int32 {get set}
    var port: in_port_t? {get set}
}

public class SXServerSocket : SXLocalSocket, SXBindedSocket {
    
    /* SXLocalSocket */
    public var sockfd: Int32
    public var domain: SXSocketDomains
    public var type: SXSocketTypes
    public var `protocol`: Int32
    public var port: in_port_t?
    public var bufsize: Int
    
    public var address : SXSockaddr
    
    init(port: in_port_t,
                  domain: SXSocketDomains,
                  type: SXSocketTypes,
                  protocol: Int32 = 0,
                  bufsize: Int) throws {
        
        self.address = try SXSockaddr(withDomain: domain, port: port)
        
        /* SXLocalSocket */
        self.port = port
        self.domain = domain
        self.`protocol` = `protocol`
        self.bufsize = bufsize
        self.type = type
        self.sockfd = socket(Int32(domain.rawValue), type.rawValue, `protocol`)
        if self.sockfd == -1 {throw SXSocketError.socket(String.errno)}
        
        try self.bind()
    }
    
    init(addr: SXSockaddr, port: in_port_t, domain: SXSocketDomains, type: SXSocketTypes, `protocol`: Int32, bufsize: Int) throws {
        
        self.address = addr
        
        /* SXLocalSocket */
        self.port = port
        self.domain = domain
        self.`protocol` = `protocol`
        self.bufsize = bufsize
        self.type = type
        self.sockfd = socket(Int32(domain.rawValue), type.rawValue, `protocol`)
        if self.sockfd == -1 {throw SXSocketError.socket(String.errno)}
        try self.bind()
    }
}

public class SXRemoteSocket: SXSocket {
    public var sockfd: Int32
    public var domain: SXSocketDomains
    public var type: SXSocketTypes
    public var `protocol`: Int32
    public var bufsize: Int
    public var addr : SXSockaddr?
    public var port: in_port_t?
    
    public init(fd: Int32, domain: SXSocketDomains, type: SXSocketTypes, `protocol`: Int32, bufsize: Int = 16384) throws {
        var caddr = sockaddr()
        var len = socklen_t()
        getsockname(fd, &caddr, &len)
        self.addr = try SXSockaddr(caddr, socklen: len)
        self.sockfd = fd
        self.domain = domain
        self.type = type
        self.`protocol` = `protocol`
        self.bufsize = bufsize
        var yes = 1
        setsockopt(sockfd, SOL_SOCKET, SO_NOSIGPIPE, &yes, UInt32(sizeof(Int32)))
    }
    
    public init(fd: Int32, domain: SXSocketDomains, type: SXSocketTypes, `protocol`: Int32, addr: sockaddr, len: socklen_t, bufsize: Int = 16384) throws {
        self.addr = try SXSockaddr(addr, socklen: len)
        self.sockfd = fd
        self.domain = domain
        self.type = type
        self.`protocol` = `protocol`
        self.bufsize = bufsize
    }
}

public class SXRemoteStreamSocket : SXRemoteSocket, SXStreamProtocol {
    public override init(fd: Int32, domain: SXSocketDomains, type: SXSocketTypes, protocol: Int32, bufsize: Int) throws {
        try super.init(fd: fd, domain: domain, type: type, protocol: `protocol`, bufsize: bufsize)
    }
    
    public init(socket: SXRemoteSocket) throws {
        try super.init(fd: socket.sockfd, domain: socket.domain, type: socket.type, protocol: socket.`protocol`)
    }
}

public class SXRemoteDGRAMSocket : SXRemoteSocket, SXDGRAMProtocol {
    public override init(fd: Int32, domain: SXSocketDomains, type: SXSocketTypes, protocol: Int32, bufsize: Int) throws {
        try super.init(fd: fd, domain: domain, type: type, protocol: `protocol`, bufsize: bufsize)
    }
    
    public init(socket: SXRemoteSocket) throws {
        try super.init(fd: socket.sockfd, domain: socket.domain, type: socket.type, protocol: socket.`protocol`)
    }
}
