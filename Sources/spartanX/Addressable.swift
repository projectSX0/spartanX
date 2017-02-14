
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
//  Created by Yuji on 9/24/16.
//  Copyright © 2016 yuuji. All rights reserved.
//

#if os(OSX) || os(iOS) || os(watchOS) || os(tvOS)
import Darwin
#else
import Glibc
#endif
import func CKit.pointer

public protocol Addressable {
    var address: SXSocketAddress? { get set }
    var port: in_port_t? { get set }
}

public extension Addressable where Self : Socket {
    public func bind() throws {
        var err: Int32 = 0
        
        var yes = true
        
        if setsockopt(sockfd, SOL_SOCKET, SO_REUSEADDR, &yes, UInt32(MemoryLayout<Int32>.size)) == -1 {
            throw SocketError.setsockopt(String.errno)
        }
        
        guard let address = address else {
            throw SocketError.bind("address is nil")
        }
        
        switch address {
        case var .inet(addr):
            #if os(OSX) || os(iOS) || os(watchOS) || os(tvOS)
            err = Darwin.bind(sockfd, pointer(of: &addr).cast(to: sockaddr.self), socklen_t(MemoryLayout<sockaddr_in>.size))
            #else
            err = Glibc.bind(sockfd, pointer(of: &addr).cast(to: sockaddr.self), socklen_t(MemoryLayout<sockaddr_in>.size))
            #endif
            
        case var .inet6(addr):
            #if os(OSX) || os(iOS) || os(watchOS) || os(tvOS)
            err = Darwin.bind(sockfd, pointer(of: &addr).cast(to : sockaddr.self), socklen_t(MemoryLayout<sockaddr_in6>.size))
            #else
            err = Glibc.bind(sockfd, pointer(of: &addr).cast(to : sockaddr.self), socklen_t(MemoryLayout<sockaddr_in6>.size))
            #endif
        case var .unix(addr):
            #if os(OSX) || os(iOS) || os(watchOS) || os(tvOS)
            err = Darwin.bind(sockfd, pointer(of: &addr).cast(to: sockaddr.self), socklen_t(MemoryLayout<sockaddr_un>.size))
            #else
            err = Glibc.bind(sockfd, pointer(of: &addr).cast(to: sockaddr.self), socklen_t(MemoryLayout<sockaddr_un>.size))
            #endif
        case var .dl(addr):
            #if os(OSX) || os(iOS) || os(watchOS) || os(tvOS)
                err = Darwin.bind(sockfd, pointer(of: &addr).cast(to: sockaddr.self), socklen_t(MemoryLayout<sockaddr_un>.size))
            #else
                err = Glibc.bind(sockfd, pointer(of: &addr).cast(to: sockaddr.self), socklen_t(MemoryLayout<sockaddr_dl>.size))
            #endif
        }
        
        if err == -1 {
            throw SocketError.bind(String.errno)
        }
    }
}
