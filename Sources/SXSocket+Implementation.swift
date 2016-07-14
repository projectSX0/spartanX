
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
//  Created by Yuji on 6/4/16.
//  Copyright © 2016 yuuji. All rights reserved.
//

import Foundation

public extension SXLocal where Self : SXSocket {

    public func bind() throws {
        var err: Int32 = 0

        var yes = true
        
        if setsockopt(sockfd, SOL_SOCKET, SO_REUSEADDR, &yes, UInt32(sizeof(Int32.self))) == -1 {
            throw SXSocketError.setSockOpt(String.errno)
        }
        
        guard let address = address else {
            throw SXSocketError.bind("address is nil")
        }

        switch address {
        case var .INET(addr):
            err = Foundation.bind(sockfd, UnsafePointer<sockaddr>(pointer(of: &addr)), socklen_t(sizeof(sockaddr_in.self)))

        case var .INET6(addr):
            err = Foundation.bind(sockfd, UnsafePointer<sockaddr>(pointer(of: &addr)), socklen_t(sizeof(sockaddr_in6.self)))

        case var .UNIX(addr):
            err = Foundation.bind(sockfd, UnsafePointer<sockaddr>(pointer(of: &addr)), socklen_t(sizeof(sockaddr_un.self)))
        }


        if err == -1 {
            throw SXSocketError.bind(String.errno)
        }
    }

    public func accept(bufsize: Int = 16384) throws -> SXRemoteSocket {
        var addr = sockaddr()
        var socklen = socklen_t()
        let fd = Foundation.accept(sockfd, &addr, &socklen)
        
        return try SXRemoteSocket(fd: fd,
                                  addr: addr,
                                  len: socklen,
                                  type: self.type,
                                  protocol: self.`protocol`,
                                  bufsize: bufsize)
    }
    
    public func listen(backlog: Int) throws {
        if Foundation.listen(sockfd, Int32(backlog)) == -1 {
            throw SXSocketError.listen(String.errno)
        }
    }
}

extension SXSocket {
    
    public func close() {
        _ = Foundation.close(self.sockfd)
    }
    
    public mutating func connect(with address: SXSocketAddress) throws {
        var i: Int32 = 0
        
        self.address = address
        
        if self.type != .stream {
            throw SXSocketError.socket("connect only can use on stream socket")
        }
        
        switch self.address! {
        case var .INET(addr):
            i = Foundation.connect(sockfd, UnsafePointer<sockaddr>(pointer(of: &addr)), socklen_t(sizeof(sockaddr_in.self)))
            
        case var .INET6(addr):
            i = Foundation.connect(sockfd, UnsafePointer<sockaddr>(pointer(of: &addr)), socklen_t(sizeof(sockaddr_in6.self)))
            
        case var .UNIX(addr):
            i = Foundation.connect(sockfd, UnsafePointer<sockaddr>(pointer(of: &addr)), socklen_t(sizeof(sockaddr_un.self)))
        }
        
        if i == -1 {
            throw SXSocketError.connect(String.errno)
        }
    }
    
    public func receive(size: Int, flags: Int32) throws -> Data {
        #if swift(>=3)
            var buffer = [UInt8](repeating: 0, count: size)
        #else
            var buffer = [UInt8](count: size, repeatedValue: 0)
        #endif
        let len = recv(sockfd, &buffer, size, flags)
        if len == -1 {throw SXSocketError.recv(String.errno)}
        #if swift(>=3)
            return Data(bytes: buffer, count: len)
        #else
            return NSMutableData(bytes: buffer, length: len)
        #endif
    }

    #if swift(>=3)
    public func recvFrom(addr: SXSocketAddress, flags: Int32 = 0) -> Data {
        var addr_ = addr // since the expression var addr: SXSocketAddrss is not compatible with Swift 3
        var socklen = addr.socklen

        var buf = [UInt8](repeating: 0, count: bufsize)

        let len = recvfrom(sockfd, &buf, bufsize, flags, UnsafeMutablePointer<sockaddr>(mutablePointer(of: &addr_)), &socklen)

        return Data(bytes: buf, count: len)
    }
    #else
    public func recvFrom(addr addr: SXSocketAddress, flags: Int32 = 0) -> NSData {
        var addr_ = addr // since the expression var addr: SXSocketAddrss is not compatible with Swift 3
        var socklen = addr.socklen
        var buf = [UInt8](count: bufsize, repeatedValue: 0)

        let len = recvfrom(sockfd, &buf, bufsize, flags, UnsafeMutablePointer<sockaddr>(getMutablePointer(&addr_)), &socklen)
        return NSData(bytes: buf, length: len)
    }
    #endif

    public func sendTo(addr: SXSocketAddress, data: Data, flags: Int32 = 0) {
        var addr_ = addr
        sendto(sockfd, data.bytes, data.length, flags, UnsafeMutablePointer<sockaddr>(mutablePointer(of: &addr_)), addr_.socklen)
    }
    
    public func send(data: Data, flags: Int32) throws {
        if Foundation.send(sockfd, data.bytes, data.length, flags) == -1 {
            throw SXSocketError.send("send: \(String.errno)")
        }
    }
}
