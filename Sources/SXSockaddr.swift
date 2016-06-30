
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

public enum DNSLookupHint {
    case Flags(Int32)
    case Family(Int32)
    case SockType(Int32)
    case `Protocol`(Int32)
    case Canonname(String)
}

public enum SXSockaddr {
    case INET(sockaddr_in)
    case INET6(sockaddr_in6)
    
    public func getIpAddress() -> String {
        
        #if swift(>=3)
        var buffer = [Int8](repeating: 0, count: Int(INET6_ADDRSTRLEN))
        #else
        var buffer = [Int8](count: Int(INET6_ADDRSTRLEN), repeatedValue: 0)
        #endif
        switch self {
        case var .INET(`in`):
            inet_ntop(AF_INET, getpointer(&`in`.sin_addr) , &buffer, socklen_t(sizeof(sockaddr_in)))
        case var .INET6(in6):
            inet_ntop(AF_INET6, getpointer(&in6.sin6_addr) , &buffer, socklen_t(sizeof(sockaddr_in6)))
        }
        #if swift(>=3)
        return String(cString: buffer)
        #else
        return String(CString: buffer, encoding: NSASCIIStringEncoding)!
        #endif
    }
    
    public func resolveDomain() -> SXSocketDomains? {
        switch self.socklen {
        case UInt32(sizeof(sockaddr_in)):
            return .INET
        case UInt32(sizeof(sockaddr_in6)):
            return .INET6
            
        default: return nil
        }
    }
    
    public init(_ addr_: sockaddr, socklen: socklen_t) throws {
        var addr = addr_
        switch socklen {
        case UInt32(sizeof(sockaddr_in)):
            self = .INET(UnsafeMutablePointer<sockaddr_in>(getMutablePointer(&addr)).pointee)
            
        case UInt32(sizeof(sockaddr_in6)):
            self = .INET6(UnsafeMutablePointer<sockaddr_in6>(getMutablePointer(&addr)).pointee)
            
        default:
            throw SXSocketError.nonImplementedDomain
        }
    }
    
    public static func boardcastAddr(port port: in_port_t = 0) throws -> SXSockaddr {
        return SXSockaddr(address: "255.255.255.255", withDomain: .INET, port: port)!
    }
    
    public init(withDomain domain: SXSocketDomains, port: in_port_t) throws {
        switch domain {
        case .INET:
            self = SXSockaddr.INET( sockaddr_in(sin_len: UInt8(sizeof(sockaddr_in)),
                                                sin_family: UInt8(AF_INET),
                                                sin_port: port.bigEndian,
                                                sin_addr: in_addr(s_addr: 0),
                                                sin_zero: (0,0,0,0,0,0,0,0)))
        case .INET6:
            self = SXSockaddr.INET6(sockaddr_in6(sin6_len: UInt8(sizeof(sockaddr_in6)),
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
           var sockaddr = sockaddr_in(sin_len: UInt8(sizeof(sockaddr_in)),
                sin_family: UInt8(AF_INET),
                sin_port: port.bigEndian,
                sin_addr: in_addr(s_addr: 0),
                sin_zero: (0,0,0,0,0,0,0,0))

            inet_pton(AF_INET,
                  address.cString(using: .ascii),
                  UnsafeMutablePointer<Void>(getMutablePointer(&sockaddr.sin_addr)))

            self = .INET(sockaddr)
            
        case .INET6:
            var sockaddr = sockaddr_in6(sin6_len: UInt8(sizeof(sockaddr_in6)),
                                    sin6_family: domain.rawValue,
                                    sin6_port: port.bigEndian,
                                    sin6_flowinfo: 0,
                                    sin6_addr: in6addr_any,
                                    sin6_scope_id: 0)
   
            inet_pton(AF_INET6,
                      address.cString(using: .ascii),
                      UnsafeMutablePointer<Void>(getMutablePointer(&sockaddr.sin6_addr)))

            self = .INET6(sockaddr)
            
        default:
            return nil
        }
    }
    
    public var socklen: socklen_t {
        get {
            switch self {
            case .INET6(_):
                return socklen_t(sizeof(sockaddr_in6))
            case .INET(_):
                return socklen_t(sizeof(sockaddr_in))
            }
        }
    }
    #if swift(>=3)
    public static func DNSLookup(hostname: String, service: String, hints: [DNSLookupHint] = []) throws -> SXSockaddr? {
        
        var info: UnsafeMutablePointer<addrinfo>? = nil
        var cinfo: UnsafeMutablePointer<addrinfo>? = nil
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
                
                ret = SXSockaddr.INET(  sockaddr_in(sin_len: UInt8(sizeof(sockaddr_in)),
                                                    sin_family: UInt8(AF_INET),
                                                    sin_port: port,
                                                    sin_addr: UnsafeMutablePointer<sockaddr_in>(addr!).pointee.sin_addr,
                                                    sin_zero: (0,0,0,0,0,0,0,0)))
                clean()
                return ret
                
            case AF_INET6:
                
                ret = SXSockaddr.INET6(sockaddr_in6(sin6_len: UInt8(sizeof(sockaddr_in6)),
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

