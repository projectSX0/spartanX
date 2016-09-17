
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
//  Created by Yuji on 9/17/16.
//  Copyright © 2016 yuuji. All rights reserved.
//

#if os(OSX) || os(iOS) || os(watchOS) || os(tvOS)
import Darwin
#else
import Glibc
#endif

public struct DNS {
    public enum LookupHint {
        case Flags(Int32)
        case Family(Int32)
        case SockType(Int32)
        case `Protocol`(Int32)
        case Canonname(String)
    }
    
    public enum Error: Swift.Error {
        case getaddrinfo(String)
        case unknownDomain
    }
}

public extension DNS {
    
    public static func lookup(hostname: String, service: String, hints: DNS.LookupHint...) throws -> [SXSocketAddress] {
        var info: UnsafeMutablePointer<addrinfo>? = nil
        var cinfo: UnsafeMutablePointer<addrinfo>? = nil
        var ret = [SXSocketAddress]()
        
        var hint = addrinfo()
        for hint_ in hints {
            switch hint_ {
            case var .Flags(i): hint.ai_flags = i
            case var .Family(i): hint.ai_family = i
            case var .SockType(i): hint.ai_socktype = i
            case var .Protocol(i): hint.ai_protocol = i
            case var .Canonname(s):
                var ss = s.cInt8String ?? []
                hint.ai_canonname = UnsafeMutablePointer<Int8>(mutating: ss)
            }
        }
        
        if getaddrinfo(hostname.cString(using: .ascii)!,
                       service.cString(using: .ascii)!,
                       &hint,
                       &info) != 0 {
            
            throw DNS.Error.getaddrinfo(String.errno)
        }
        
        func clean() {
            freeaddrinfo(info)
        }
        
        defer {
            clean()
        }
        
        cinfo = info
        
        while cinfo != nil {
            cinfo = cinfo!.pointee.ai_next
            
            let port = (UInt16(getservbyname(service.cString(using: String.Encoding.ascii)!, nil).pointee.s_port))
            
            if cinfo == nil {
                continue
            }
            
            let addr = cinfo!.pointee.ai_addr
            
            switch cinfo!.pointee.ai_family {
                
            case AF_INET:
                let addr = SXSocketAddress.inet(sockaddr_in(port: port,
                                                            addr: addr!.cast(to: sockaddr_in.self).pointee.sin_addr))
                ret.append(addr)
                
            case AF_INET6:
                let addr = SXSocketAddress.inet6(sockaddr_in6(port: port,
                                                              addr: addr!.cast(to: sockaddr_in6.self).pointee.sin6_addr))
                ret.append(addr)
                
            default:
                continue;
            }
        }
        
        return ret
    }
    
    public static func lookup_once(hostname: String, service: String, hints: DNS.LookupHint...) throws -> SXSocketAddress? {
        var info: UnsafeMutablePointer<addrinfo>? = nil
        var cinfo: UnsafeMutablePointer<addrinfo>? = nil
        var ret: SXSocketAddress
        
        var hint = addrinfo()
        for hint_ in hints {
            switch hint_ {
            case var .Flags(i): hint.ai_flags = i
            case var .Family(i): hint.ai_family = i
            case var .SockType(i): hint.ai_socktype = i
            case var .Protocol(i): hint.ai_protocol = i
            case var .Canonname(s):
                var ss = s.cInt8String ?? []
                hint.ai_canonname = UnsafeMutablePointer<Int8>(mutating: ss)
            }
        }
        
        if getaddrinfo(hostname.cString(using: .ascii)!,
                       service.cString(using: .ascii)!,
                       &hint,
                       &info) != 0 {
            
            throw DNS.Error.getaddrinfo(String.errno)
        }
        
        defer {
            freeaddrinfo(info)
        }
        
        cinfo = info
        
        while cinfo != nil {
            cinfo = cinfo!.pointee.ai_next
            let port = (UInt16(getservbyname(service.cString(using: String.Encoding.ascii)!, nil).pointee.s_port))
            let addr = cinfo!.pointee.ai_addr
            switch cinfo!.pointee.ai_family {
            case AF_INET:
                ret = SXSocketAddress.inet(sockaddr_in(port: port,
                                                       addr: addr!.cast(to: sockaddr_in.self).pointee.sin_addr))
                return ret
                
            case AF_INET6:
                ret = SXSocketAddress.inet6(sockaddr_in6(port: port,
                                                         addr: addr!.cast(to: sockaddr_in6.self).pointee.sin6_addr))
                return ret
                
            default:
                continue;
            }
        }
        
        return nil
    }
    
    public static func lookup(hostname: String, port:in_port_t, hints: DNS.LookupHint...) throws -> [SXSocketAddress] {
        
        var info: UnsafeMutablePointer<addrinfo>? = nil
        var cinfo: UnsafeMutablePointer<addrinfo>? = nil
        var ret = [SXSocketAddress]()
        
        var hint = addrinfo()
        for hint_ in hints {
            switch hint_ {
            case var .Flags(i): hint.ai_flags = i
            case var .Family(i): hint.ai_family = i
            case var .SockType(i): hint.ai_socktype = i
            case var .Protocol(i): hint.ai_protocol = i
            case var .Canonname(s):
                var ss = s.cInt8String ?? []
                hint.ai_canonname = UnsafeMutablePointer<Int8>(mutating: ss)
            }
        }
        
        if getaddrinfo(hostname.cString(using: .ascii)!,
                       nil,
                       &hint,
                       &info) != 0 {
            
            throw DNS.Error.getaddrinfo(String.errno)
        }
        
        
        defer {
            freeaddrinfo(info)
        }
        
        cinfo = info
        
        while cinfo != nil {
            cinfo = cinfo!.pointee.ai_next
            let addr = cinfo!.pointee.ai_addr
            switch cinfo!.pointee.ai_family {
            case AF_INET:
                let addr = SXSocketAddress.inet(sockaddr_in(port: port,
                                                            addr: addr!.cast(to: sockaddr_in.self).pointee.sin_addr))
                ret.append(addr)
            case AF_INET6:
                let addr = SXSocketAddress.inet6(sockaddr_in6(port: port,
                                                              addr: addr!.cast(to: sockaddr_in6.self).pointee.sin6_addr))
                ret.append(addr)
            default:
                continue;
            }
        }
        
        return ret
    }
    
    public static func lookup_once(hostname: String, port: in_port_t, hints: DNS.LookupHint...) throws -> SXSocketAddress? {
        
        var info: UnsafeMutablePointer<addrinfo>? = nil
        var cinfo: UnsafeMutablePointer<addrinfo>? = nil
        var ret: SXSocketAddress
        
        var hint = addrinfo()
        for hint_ in hints {
            switch hint_ {
            case var .Flags(i): hint.ai_flags = i
            case var .Family(i): hint.ai_family = i
            case var .SockType(i): hint.ai_socktype = i
            case var .Protocol(i): hint.ai_protocol = i
            case var .Canonname(s):
                var ss = s.cInt8String ?? []
                hint.ai_canonname = UnsafeMutablePointer<Int8>(mutating: ss)
            }
        }
        
        if getaddrinfo(hostname.cString(using: .ascii)!,
                       nil,
                       &hint,
                       &info) != 0 {
            
            throw DNS.Error.getaddrinfo(String.errno)
        }
        
        func clean() {
            freeaddrinfo(info)
        }
        
        defer {
            clean()
        }
        
        cinfo = info
        
        while cinfo != nil {
            cinfo = cinfo!.pointee.ai_next
            
            let addr = cinfo!.pointee.ai_addr
            
            switch cinfo!.pointee.ai_family {
            case AF_INET:
                ret = SXSocketAddress.inet(sockaddr_in(port: port,
                                                       addr: addr!.cast(to: sockaddr_in.self).pointee.sin_addr))
                return ret
                
            case AF_INET6:
                ret = SXSocketAddress.inet6(sockaddr_in6(port: port,
                                                         addr: addr!.cast(to: sockaddr_in6.self).pointee.sin6_addr))
                return ret
                
            default:
                continue;
            }
        }
        
        return nil
    }
    
    
}
