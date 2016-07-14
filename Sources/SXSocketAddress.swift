
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
//  Created by Yuji on 6/2/16.
//  Copyright © 2016 yuuji. All rights reserved.
//

import Foundation

#if os(OSX) || os(iOS) || os(watchOS) || os(tvOS)
public let UNIX_PATH_MAX = 104
#elseif os(FreeBSD)
public let UNIX_PATH_MAX = 108
#endif

public enum DNSLookupHint {
    case Flags(Int32)
    case Family(Int32)
    case SockType(Int32)
    case `Protocol`(Int32)
    case Canonname(String)
}

public enum SXSocketAddress {
    case INET(sockaddr_in)
    case INET6(sockaddr_in6)
    case UNIX(sockaddr_un)
    
    public func getIpAddress() -> String {
        
        #if swift(>=3)
        var buffer = [Int8](repeating: 0, count: Int(PATH_MAX))
        #else
        var buffer = [Int8](count: Int(255), repeatedValue: 0)
        #endif
        switch self {
        case var .INET(`in`):
            inet_ntop(AF_INET, getpointer(&`in`.sin_addr) , &buffer, socklen_t(sizeof(sockaddr_in.self)))
        case var .INET6(in6):
            inet_ntop(AF_INET6, getpointer(&in6.sin6_addr) , &buffer, socklen_t(sizeof(sockaddr_in6.self)))
        case var .UNIX(un):
            strncpy(&buffer, UnsafePointer<Int8>(getpointer(&un.sun_path)), Int(PATH_MAX))
        }
        #if swift(>=3)
        return String(cString: buffer)
        #else
        return String(CString: buffer, encoding: NSASCIIStringEncoding)!
        #endif
    }
    
    public func resolveDomain() -> SXSocketDomains? {
        switch self.socklen {
        case UInt32(sizeof(sockaddr_in.self)):
            return .INET
        case UInt32(sizeof(sockaddr_in6.self)):
            return .INET6
            
        default: return nil
        }
    }
    
    public init(_ addr_: sockaddr, socklen: socklen_t) throws {
        var addr = addr_
        switch socklen {
        case UInt32(sizeof(sockaddr_in.self)):
            self = .INET(UnsafeMutablePointer<sockaddr_in>(getMutablePointer(&addr)).pointee)
            
        case UInt32(sizeof(sockaddr_in6.self)):
            self = .INET6(UnsafeMutablePointer<sockaddr_in6>(getMutablePointer(&addr)).pointee)
            
        default:
            throw SXSocketError.nonImplementedDomain
        }
    }
    
    public static func boardcastAddr(port: in_port_t = 0) throws -> SXSocketAddress {
        return SXSocketAddress(address: "255.255.255.255", withDomain: .INET, port: port)!
    }
    
    public init(withDomain domain: SXSocketDomains, port: in_port_t) throws {
        switch domain {
        case .INET:
            self = SXSocketAddress.INET( sockaddr_in(sin_len: UInt8(sizeof(sockaddr_in.self)),
                                                sin_family: UInt8(AF_INET),
                                                sin_port: port.bigEndian,
                                                sin_addr: in_addr(s_addr: 0),
                                                sin_zero: (0,0,0,0,0,0,0,0)))
        case .INET6:
            self = SXSocketAddress.INET6(sockaddr_in6(sin6_len: UInt8(sizeof(sockaddr_in6.self)),
                                                sin6_family: domain.rawValue,
                                                sin6_port: port.bigEndian,
                                                sin6_flowinfo: 0,
                                                sin6_addr: in6addr_any,
                                                sin6_scope_id: 0))
        default:
            throw SXSocketError.nonImplementedDomain
        }
    }
    
    public init?(address: String, withDomain domain: SXSocketDomains, port: in_port_t) {
        switch domain {
            
        case .INET:
           var sockaddr = sockaddr_in(sin_len: UInt8(sizeof(sockaddr_in.self)),
                sin_family: UInt8(AF_INET),
                sin_port: port.bigEndian,
                sin_addr: in_addr(s_addr: 0),
                sin_zero: (0,0,0,0,0,0,0,0))

            inet_pton(AF_INET,
                  address.cString(using: .ascii),
                  UnsafeMutablePointer<Void>(getMutablePointer(&sockaddr.sin_addr)))

            self = .INET(sockaddr)
            
        case .INET6:
            var sockaddr = sockaddr_in6(sin6_len: UInt8(sizeof(sockaddr_in6.self)),
                                    sin6_family: domain.rawValue,
                                    sin6_port: port.bigEndian,
                                    sin6_flowinfo: 0,
                                    sin6_addr: in6addr_any,
                                    sin6_scope_id: 0)
   
            inet_pton(AF_INET6,
                      address.cString(using: .ascii),
                      UnsafeMutablePointer<Void>(getMutablePointer(&sockaddr.sin6_addr)))

            self = .INET6(sockaddr)
            
        case .UNIX:
            var sockaddr = sockaddr_un()
            sockaddr.sun_family = UInt8(AF_UNIX)
            sockaddr.sun_len = UInt8(sizeof(sockaddr_un.self))
            let cstr = address.cString(using: .utf8)!
            strncpy(UnsafeMutablePointer<Int8>(getMutablePointer(&(sockaddr.sun_path))), cstr, UNIX_PATH_MAX)
            
            self = .UNIX(sockaddr)
            
        default:
            return nil
        }
    }
    
    public var socklen: socklen_t {
        get {
            switch self {
            case .INET6(_):
                return socklen_t(sizeof(sockaddr_in6.self))
            case .INET(_):
                return socklen_t(sizeof(sockaddr_in.self))
            case .UNIX(_):
                return socklen_t(sizeof(sockaddr_un.self))
            }
        }
    }
    
    #if swift(>=3)
    public static func DNSLookup(hostname: String, service: String, hints: [DNSLookupHint] = []) throws -> SXSocketAddress? {
        
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
                hint.ai_canonname = UnsafeMutablePointer<Int8>(ss)
            }
        }
        
        if getaddrinfo(hostname.cString(using: .ascii)!,
                       service.cString(using: .ascii)!,
                       &hint,
                       &info) != 0 {
            
            throw SXAddrError.getAddrInfo(String.errno)
        }
        
        func clean() {
            freeaddrinfo(info)
        }
        
        cinfo = info
        
        while cinfo != nil {
            cinfo = cinfo!.pointee.ai_next
            
            let port = (UInt16(getservbyname(service.cString(using: String.Encoding.ascii)!, nil).pointee.s_port))
            
            let addr = cinfo!.pointee.ai_addr
            
            switch cinfo!.pointee.ai_family {
            case AF_INET:
                
                ret = SXSocketAddress.INET(  sockaddr_in(sin_len: UInt8(sizeof(sockaddr_in.self)),
                                                    sin_family: UInt8(AF_INET),
                                                    sin_port: port,
                                                    sin_addr: UnsafeMutablePointer<sockaddr_in>(addr!).pointee.sin_addr,
                                                    sin_zero: (0,0,0,0,0,0,0,0)))
                clean()
                return ret
                
            case AF_INET6:
                
                ret = SXSocketAddress.INET6(sockaddr_in6(sin6_len: UInt8(sizeof(sockaddr_in6.self)),
                                                    sin6_family: UInt8(AF_INET6),
                                                    sin6_port: port,
                                                    sin6_flowinfo: 0,
                                                    sin6_addr: UnsafeMutablePointer<sockaddr_in6>(addr!).pointee.sin6_addr,
                                                    sin6_scope_id: 0))
                clean()
                return ret
                
            default:
                continue;
            }
        }
        
        return nil
    }
    
    public static func DNSLookup(hostname: String, service: String, hints: [DNSLookupHint] = []) throws -> [SXSocketAddress] {
        
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
                hint.ai_canonname = UnsafeMutablePointer<Int8>(ss)
            }
        }
        
        if getaddrinfo(hostname.cString(using: .ascii)!,
                       service.cString(using: .ascii)!,
                       &hint,
                       &info) != 0 {
            
            throw SXAddrError.getAddrInfo(String.errno)
        }
        
        func clean() {
            freeaddrinfo(info)
        }
        
        cinfo = info
        
        while cinfo != nil {
            cinfo = cinfo!.pointee.ai_next
            
            let port = (UInt16(getservbyname(service.cString(using: String.Encoding.ascii)!, nil).pointee.s_port))
            
            let addr = cinfo!.pointee.ai_addr
            
            switch cinfo!.pointee.ai_family {
                
            case AF_INET:
                
                let addr = SXSocketAddress.INET(  sockaddr_in(sin_len: UInt8(sizeof(sockaddr_in.self)),
                                                    sin_family: UInt8(AF_INET),
                                                    sin_port: port,
                                                    sin_addr: UnsafeMutablePointer<sockaddr_in>(addr!).pointee.sin_addr,
                                                    sin_zero: (0,0,0,0,0,0,0,0)))
                ret.append(addr)
                
            case AF_INET6:
                
                let addr = SXSocketAddress.INET6(sockaddr_in6(sin6_len: UInt8(sizeof(sockaddr_in6.self)),
                                                    sin6_family: UInt8(AF_INET6),
                                                    sin6_port: port,
                                                    sin6_flowinfo: 0,
                                                    sin6_addr: UnsafeMutablePointer<sockaddr_in6>(addr!).pointee.sin6_addr,
                                                    sin6_scope_id: 0))

                ret.append(addr)
                
            default:
                continue;
            }
        }
        
        clean()
        
        return ret
    }
    
    public static func DNSLookup(hostname: String, port: in_port_t, hints: [DNSLookupHint] = []) throws -> SXSocketAddress? {
        
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
                hint.ai_canonname = UnsafeMutablePointer<Int8>(ss)
            }
        }
        
        if getaddrinfo(hostname.cString(using: .ascii)!,
                       nil,
                       &hint,
                       &info) != 0 {
            
            throw SXAddrError.getAddrInfo(String.errno)
        }
        
        func clean() {
            freeaddrinfo(info)
        }
        
        cinfo = info
        
        while cinfo != nil {
            cinfo = cinfo!.pointee.ai_next
            
//            let port = (UInt16(getservbyname(service.cString(using: String.Encoding.ascii)!, nil).pointee.s_port))
            
            let addr = cinfo!.pointee.ai_addr
            
            switch cinfo!.pointee.ai_family {
            case AF_INET:
                
                ret = SXSocketAddress.INET(  sockaddr_in(sin_len: UInt8(sizeof(sockaddr_in.self)),
                                                    sin_family: UInt8(AF_INET),
                                                    sin_port: port,
                                                    sin_addr: UnsafeMutablePointer<sockaddr_in>(addr!).pointee.sin_addr,
                                                    sin_zero: (0,0,0,0,0,0,0,0)))
                clean()
                return ret
                
            case AF_INET6:
                
                ret = SXSocketAddress.INET6(sockaddr_in6(sin6_len: UInt8(sizeof(sockaddr_in6.self)),
                                                    sin6_family: UInt8(AF_INET6),
                                                    sin6_port: port,
                                                    sin6_flowinfo: 0,
                                                    sin6_addr: UnsafeMutablePointer<sockaddr_in6>(addr!).pointee.sin6_addr,
                                                    sin6_scope_id: 0))
                clean()
                return ret
                
            default:
                continue;
            }
        }
        
        return nil
    }
    
    public static func DNSLookup(hostname: String, port:in_port_t, hints: [DNSLookupHint] = []) throws -> [SXSocketAddress] {
        
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
                hint.ai_canonname = UnsafeMutablePointer<Int8>(ss)
            }
        }
        
        if getaddrinfo(hostname.cString(using: .ascii)!,
                       nil,
                       &hint,
                       &info) != 0 {
            
            throw SXAddrError.getAddrInfo(String.errno)
        }
        
        func clean() {
            freeaddrinfo(info)
        }
        
        cinfo = info
        
        while cinfo != nil {
            cinfo = cinfo!.pointee.ai_next
            
//            let port = (UInt16(getservbyname(service.cString(using: String.Encoding.ascii)!, nil).pointee.s_port))
            
            let addr = cinfo!.pointee.ai_addr
            
            switch cinfo!.pointee.ai_family {
                
            case AF_INET:
                
                let addr = SXSocketAddress.INET(  sockaddr_in(sin_len: UInt8(sizeof(sockaddr_in.self)),
                                                         sin_family: UInt8(AF_INET),
                                                         sin_port: port,
                                                         sin_addr: UnsafeMutablePointer<sockaddr_in>(addr!).pointee.sin_addr,
                                                         sin_zero: (0,0,0,0,0,0,0,0)))
                ret.append(addr)
                
            case AF_INET6:
                
                let addr = SXSocketAddress.INET6(sockaddr_in6(sin6_len: UInt8(sizeof(sockaddr_in6.self)),
                                                         sin6_family: UInt8(AF_INET6),
                                                         sin6_port: port,
                                                         sin6_flowinfo: 0,
                                                         sin6_addr: UnsafeMutablePointer<sockaddr_in6>(addr!).pointee.sin6_addr,
                                                         sin6_scope_id: 0))
                
                ret.append(addr)
                
            default:
                continue;
            }
        }
        
        clean()
        
        return ret
    }
    #else
    public static func DNSLookup(hostname hostname: String, service: String, hints: [DNSLookupHint] = []) throws -> SXSockaddr? {
        
        var info: UnsafeMutablePointer<addrinfo> = nil
        var cinfo: UnsafeMutablePointer<addrinfo> = nil
        var ret: SXSockaddr

            var hint = addrinfo()
            for hint_ in hints {
                switch hint_ {
                case var .Flags(i): hint.ai_flags = i
                case var .Family(i): hint.ai_family = i
                case var .SockType(i): hint.ai_socktype = i
                case var .Protocol(i): hint.ai_protocol = i
                case var .Canonname(s):
                    var ss = s.cInt8String ?? []
                    hint.ai_canonname = UnsafeMutablePointer<Int8>(ss)
                }
            }
        
        if getaddrinfo(hostname.cStringUsingEncoding(NSASCIIStringEncoding)!,
                       service.cStringUsingEncoding(NSASCIIStringEncoding)!,
                       &hint,
                       &info) != 0 {
            
            throw SXAddrError.getAddrInfo(String.errno)
        }
        
        func clean() {
            freeaddrinfo(info)
        }
        
        cinfo = info
        
        while cinfo != nil {
            cinfo = cinfo.pointee.ai_next

            let port = CFSwapInt16HostToBig(UInt16(getservbyname(service.cStringUsingEncoding(NSASCIIStringEncoding)!, nil).pointee.s_port)).byteSwapped
            
            let addr = cinfo.pointee.ai_addr
        
            switch cinfo.pointee.ai_family {
            case AF_INET:
                
                ret = SXSockaddr.INET(  sockaddr_in(sin_len: UInt8(sizeof(sockaddr_in)),
                                                    sin_family: UInt8(AF_INET),
                                                    sin_port: port,
                                                    sin_addr: UnsafeMutablePointer<sockaddr_in>(addr).pointee.sin_addr,
                                                    sin_zero: (0,0,0,0,0,0,0,0)))
                clean()
                return ret
                
            case AF_INET6:
                
                ret = SXSockaddr.INET6(sockaddr_in6(sin6_len: UInt8(sizeof(sockaddr_in6)),
                                                    sin6_family: UInt8(AF_INET6),
                                                    sin6_port: port,
                                                    sin6_flowinfo: 0,
                                                    sin6_addr: UnsafeMutablePointer<sockaddr_in6>(addr).pointee.sin6_addr,
                                                    sin6_scope_id: 0))
                clean()
                return ret
                
            default:
                continue;
            }
        }
        
        return nil
    }
    #endif
}

