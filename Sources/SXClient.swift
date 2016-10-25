
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

import struct Foundation.Data

#if os(Linux) || os(FreeBSD)
    import Glibc
#else
    import Darwin
#endif

public struct ClientFunctions<ClientSocketType> {
    var read: (ClientSocketType, Int) throws -> Data?
    var write: (ClientSocketType, _ data: Data) throws -> ()
    var clean: ((ClientSocketType) -> ())?
}

public struct SXClientSocket : ClientSocket {
//    
    internal var readHandler: (SXClientSocket, Int) throws -> Data?
    internal var writeHandler: (SXClientSocket, Data) throws -> ()
//    internal var _clean: ((SXClientSocket) -> ())?
//    
    public var sockfd: Int32
    public var domain: SocketDomains
    public var type: SocketTypes
    public var `protocol`: Int32
    
    public var address: SXSocketAddress?

    public var recvFlags: Int32 = 0
    public var sendFlags: Int32 = 0
    
    internal init(fd: Int32,
                  addrinfo: (addr: sockaddr, len: socklen_t),
                  sockinfo: (type: SocketTypes, `protocol`: Int32),
                  functions: ClientFunctions<SXClientSocket>
        ) throws {
        
        self.address = try SXSocketAddress(addrinfo.addr, socklen: addrinfo.len)
        self.sockfd = fd
        
        switch Int(addrinfo.len) {
        case MemoryLayout<sockaddr_in>.size:
            self.domain = .inet
        case MemoryLayout<sockaddr_in6>.size:
            self.domain = .inet6
        case MemoryLayout<sockaddr_un>.size:
            self.domain = .unix
        default:
            throw SocketError.socket("Unknown domain")
        }
        
        self.type = sockinfo.type
        self.`protocol` = sockinfo.`protocol`
        self.readHandler = functions.read
        self.writeHandler = functions.write
    }
}

public extension SXClientSocket {
    
    public static let standardIOHandlers: ClientFunctions = ClientFunctions(read: { (client: Socket & Readable, availableCount: Int) throws -> Data? in
        return client.isBlocking ?
            try client.recv_block(size: availableCount) :
            try client.recv_nonblock(size: availableCount)
        }, write: { (client: Socket & Writable, data: Data) throws -> () in
            if send(client.sockfd, data.bytes, data.length, 0) == -1 {
                throw SocketError.send("send: \(String.errno)")
            }
    }) { (_ client: SXClientSocket) in }
    
    
    public func write(data: Data) throws {
        
        try self.writeHandler(self, data)
    }
    
    public func read(size: Int) throws -> Data? {
        return try self.readHandler(self, size)
    }
    
    public func done() {
//        self._clean?(self)
        close(self.sockfd)
    }
}
