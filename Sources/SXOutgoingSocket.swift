
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
//  Created by Yuji on 9/11/16.
//  Copyright © 2016 yuuji. All rights reserved.
//

#if os(OSX) || os(iOS) || os(watchOS) || os(tvOS)
import Darwin
#else
import Glibc
#if os(Linux)
import OSHeader
#endif /* os(Linux) */
#endif /* osx ios watchos tvos*/

import CKit
import Foundation

#if __tls
    import struct swiftTLS.TLSClient
#endif

import struct Foundation.Data
import func CKit.pointer

private func connect(_ fd: Int32, _ sockaddr: UnsafePointer<sockaddr>, _ socklen_t: socklen_t) -> Int32 {
    #if os(OSX) || os(iOS) || os(watchOS) || os(tvOS)
        return Darwin.connect(fd, sockaddr, socklen_t)
    #else
        return Glibc.connect(fd, sockaddr, socklen_t)
    #endif
}

public typealias SXConnectionSocket = SXOutgoingSocket // backward support

public struct SXOutgoingSocket: OutgoingSocket
{
    static let defaultBufsize = 1048576 * 4
    public var sockfd: Int32
    public var domain: SocketDomains
    public var type: SocketTypes
    public var `protocol`: Int32
    public var port: in_port_t?
    #if __tls
    let tlsContext = TLSClient.securedClient()
    #endif
    public var address: SXSocketAddress?
    public var readBufsize: size_t
    
    var handler: ((Data?) -> Bool)?
    public var hashValue: Int
    
    public var errhandler: ((Error) -> Bool)?
    
    internal var readHandler: (Readable & Socket, Int) throws -> Data?
    internal var writeHandler: (Writable & Socket, Data) throws -> ()
}

//MARK: - runtime
extension SXOutgoingSocket {
    
    @inline(__always)
    public func write(data: Data) throws {
        if send(sockfd, data.bytes, data.length, 0) == -1 {
            throw SocketError.send("send: \(String.errno)")
        }
    }
    
    public static func oneshot(tls: Bool, hostname: String, service: String, request: Data, expectedResponseSize size: Int = SXOutgoingSocket.defaultBufsize, timeout: timeval?, callback: (Data?) -> () ) throws {
        let socket = try SXOutgoingSocket(tls: tls, hostname: hostname, service: service, bufsize: size)
        try socket.write(data: request)
        if let timeout = timeout {
            socket.setTimeoutInterval(timeout)
        }
        socket.setBlockingMode(block: false)
        let data = try socket.read(size: size)
        callback(data)
        socket.done()
    }
    
    public static func oneshot(unixDomain: String, type: SocketTypes, request: Data, expectedResponseSize size: Int = SXOutgoingSocket.defaultBufsize, timeout: timeval?, callback: (Data?) -> () ) throws {
        let socket = try SXOutgoingSocket(unixDomainName: unixDomain, type: type)
        try socket.write(data: request)
        if let timeout = timeout {
            socket.setTimeoutInterval(timeout)
        }
        socket.setBlockingMode(block: true)
        let data = try socket.read(size: size)
        callback(data)
        socket.done()
    }
    
    public func read() throws -> Data? {
        var size: Int = 0
        #if os(OSX) || os(iOS) || os(watchOS) || os(tvOS)
        let FIONREAD = 1074030207 /* Trust me, it is FIONREAD found in <sys/filio.h>, somehow it cannot import to swift */
        #endif
        _ = ioctl(sockfd, UInt(FIONREAD), UnsafeMutableRawPointer(mutablePointer(of: &size)))
        return try read(size: size)
    }

    @inline(__always)
    public func read(size: Int) throws -> Data? {
        return self.isBlocking ?
            try self.read_block(size: size) :
            try self.read_nonblock(size: size)
    }
    
    public func done() {
        close(self.sockfd)
    }
}

extension SXOutgoingSocket: KqueueManagable {

    public func runloop(manager: SXKernel, _ ev: event) {
        
        func kdone() {
            manager.remove(ident: self.ident, for: .read)
            self.done()
        }
        
        do {
            #if os(OSX) || os(iOS) || os(watchOS) || os(tvOS) || os(FreeBSD) || os(PS4)
                let payload = try self.read(size: ev.data)
            #else
                var size: Int = 0
                _ = ioctl(ev.data.fd, UInt(FIONREAD), UnsafeMutableRawPointer(mutablePointer(of: &size)))
                let payload = try self.read()
            #endif
            if handler?(payload) == false {
                kdone()
            }
        } catch {
            if let errh = errhandler {
                if !errh(error) {
                    kdone()
                }
            } else {
                kdone()
            }
        }
    }
}

//MARK: - initializers
public extension SXOutgoingSocket {
    
    public init(unixDomainName: String, type: SocketTypes, `protocol`: Int32 = 0, bufsize: Int = SXOutgoingSocket.defaultBufsize) throws {
        if type != .stream && type != .seqpacket {
            throw SocketError.unconnectable
        }
        
        self.readHandler = { client, size throws -> Data? in
            client.setBlockingMode(block: true)
            return client.isBlocking ?
                try client.recv_block(size: size) :
                try client.recv_nonblock(size: size)
        }
        
        self.writeHandler =  { (client: Socket & Writable, data: Data) throws -> () in
            if send(client.sockfd, data.bytes, data.length, 0) == -1 {
                throw SocketError.send("send: \(String.errno)")
            }
        }
        
        self.type = type
        self.domain = .unix
        self.`protocol` = `protocol`
        self.readBufsize = bufsize
        self.sockfd = socket(AF_UNIX, self.type.rawValue, `protocol`)
        self.hashValue = Int(sockfd) * time(nil)
        self.address = SXSocketAddress(address: unixDomainName, withDomain: .unix, port: 0)
        switch self.address! {
        case var .unix(addr):
            if type == .stream {
                if connect(sockfd, pointer(of: &addr).cast(to: sockaddr.self), address!.socklen) == -1 {
                    throw SocketError.connect(String.errno)
                }
            }
        default:
            break
        }
    }
    
    public init(tls: Bool = false, hostname: String, service: String, type: SocketTypes = .stream, `protocol`: Int32 = 0, bufsize: Int = SXOutgoingSocket.defaultBufsize) throws {
        let addresses: [SXSocketAddress] = try! DNS.lookup(hostname: hostname, service: service)
        var fd: Int32 = -1
        self.type = type
        self.domain = .unspec
        self.`protocol` = `protocol`
        self.readBufsize = bufsize
        
        self.readHandler = { client, size throws -> Data? in
            return client.isBlocking ?
                try client.recv_block(size: size) :
                try client.recv_nonblock(size: size)
        }
        
        self.writeHandler =  { (client: Socket & Writable, data: Data) throws -> () in
            if send(client.sockfd, data.bytes, data.length, 0) == -1 {
                throw SocketError.send("send: \(String.errno)")
            }
        }
        
        
        #if __tls
            if tls {
                self.readHandler = { client_socket, _ throws -> Data? in
                    return try (client_socket as! SXOutgoingSocket).tlsContext.read(size: 16 * 1024)
                }
                
                self.writeHandler = { client_socket, data throws in
                    _ = try client_socket.write(data: data)
                }
            }
        #endif
        
        searchAddress: for address in addresses {
            switch address {
            case var .inet(addr):
                fd = socket(AF_INET, type.rawValue, 0)
                if connect(fd, pointer(of: &addr).cast(to: sockaddr.self), address.socklen) == -1 {
                    continue
                }
                self.domain = .inet
                break searchAddress
            case var .inet6(addr):
                fd = socket(AF_INET6, type.rawValue, 0)
                if connect(fd, pointer(of: &addr).cast(to: sockaddr.self), address.socklen) == -1 {
                    continue
                }
                self.domain = .inet6
                break searchAddress
            default:
                throw SocketError.unconnectable
            }
        }
        
        if fd == -1 {
            throw SocketError.connect(String.errno)
        }
        
        self.sockfd = fd
        self.hashValue = Int(sockfd) * time(nil)
    }
    
    
    public init(tls: Bool = false, hostname: String, port: in_port_t, type: SocketTypes = .stream, `protocol`: Int32 = 0, bufsize: Int = SXOutgoingSocket.defaultBufsize) throws {
        let addresses: [SXSocketAddress] = try! DNS.lookup(hostname: hostname, port: port)
        var fd: Int32 = -1
        self.type = type
        self.domain = .unspec
        self.`protocol` = `protocol`
        self.readBufsize = bufsize
        
        self.readHandler = { client, size throws -> Data? in
            return client.isBlocking ?
                try client.recv_block(size: size) :
                try client.recv_nonblock(size: size)
        }
        
        self.writeHandler =  { (client: Socket & Writable, data: Data) throws -> () in
            if send(client.sockfd, data.bytes, data.length, 0) == -1 {
                throw SocketError.send("send: \(String.errno)")
            }
        }
        
        
        #if __tls
            if tls {
                self.readHandler = { client_socket, _ throws -> Data? in
                    return try (client_socket as! SXOutgoingSocket).tlsContext.read(size: 16 * 1024)
                }
                
                self.writeHandler = { client_socket, data throws in
                    _ = try client_socket.write(data: data)
                }
            }
        #endif
        
        
        searchAddress: for address in addresses {
            switch address {
            case var .inet(addr):
                fd = socket(AF_INET, type.rawValue, 0)
                if connect(fd, pointer(of: &addr).cast(to: sockaddr.self), address.socklen) == -1 {
                    continue
                }
                self.domain = .inet
                break searchAddress
            case var .inet6(addr):
                fd = socket(AF_INET6, type.rawValue, 0)
                
                if connect(fd, pointer(of: &addr).cast(to: sockaddr.self), address.socklen) == -1 {
                    continue
                }
                self.domain = .inet6
                break searchAddress
            default:
                throw SocketError.nonInetDomain
            }
        }
        
        if fd == -1 {
            throw SocketError.unconnectable
        }
        
        self.sockfd = fd
        self.hashValue = Int(sockfd) * time(nil)
    }
    
    public init(ipv4: String, port: in_port_t, type: SocketTypes = .stream, `protocol`: Int32 = 0, bufsize: Int = SXOutgoingSocket.defaultBufsize) throws {
        self.sockfd = socket(AF_INET, type.rawValue, `protocol`)
        self.domain = .inet
        self.type = type
        self.protocol = `protocol`
        self.address = SXSocketAddress(address: ipv4, withDomain: .inet, port: port)
        self.readBufsize = bufsize
        
        self.hashValue = Int(sockfd) * time(nil)
        
        self.readHandler = { client, size throws -> Data? in
            return client.isBlocking ?
                try client.recv_block(size: size) :
                try client.recv_nonblock(size: size)
        }
        
        self.writeHandler =  { (client: Socket & Writable, data: Data) throws -> () in
            if send(client.sockfd, data.bytes, data.length, 0) == -1 {
                throw SocketError.send("send: \(String.errno)")
            }
        }
        
        
        switch self.address! {
        case var .inet(addr):
            if connect(self.sockfd, pointer(of: &addr).cast(to: sockaddr.self), self.address!.socklen) == -1 {
                throw SocketError.connect(String.errno)
            }
        default: throw DNS.Error.unknownDomain
        }
    }
    
    public init(ipv6: String, port: in_port_t, type: SocketTypes = .stream, `protocol`: Int32 = 0, bufsize: Int = SXOutgoingSocket.defaultBufsize) throws {
        self.sockfd = socket(AF_INET6, type.rawValue, `protocol`)
        self.domain = .inet6
        self.type = type
        self.protocol = `protocol`
        self.address = SXSocketAddress(address: ipv6, withDomain: .inet6, port: port)
        self.readBufsize = bufsize
        
        self.hashValue = Int(sockfd) * time(nil)
        
        self.readHandler = { client, size throws -> Data? in
            return client.isBlocking ?
                try client.recv_block(size: size) :
                try client.recv_nonblock(size: size)
        }
        
        self.writeHandler =  { (client: Socket & Writable, data: Data) throws -> () in
            if send(client.sockfd, data.bytes, data.length, 0) == -1 {
                throw SocketError.send("send: \(String.errno)")
            }
        }
        
        switch self.address! {
        case var .inet6(addr):
            if connect(self.sockfd, pointer(of: &addr).cast(to: sockaddr.self), self.address!.socklen) == -1 {
                throw SocketError.connect(String.errno)
            }
        default: throw DNS.Error.unknownDomain
        }
    }
    
    public init?(ipv4: String, service: String, type: SocketTypes = .stream, `protocol`: Int32 = 0, bufsize: Int = SXOutgoingSocket.defaultBufsize) throws {
        let port = (UInt16(getservbyname(service.cString(using: String.Encoding.ascii)!, nil).pointee.s_port)).byteSwapped
        self.sockfd = socket(AF_INET, type.rawValue, `protocol`)
        self.domain = .inet
        self.type = type
        self.protocol = `protocol`
        self.address = SXSocketAddress(address: ipv4, withDomain: .inet, port: port)
        self.readBufsize = bufsize
        
        self.hashValue = Int(sockfd) * time(nil)
        
        self.readHandler = { client, size throws -> Data? in
            return client.isBlocking ?
                try client.recv_block(size: size) :
                try client.recv_nonblock(size: size)
        }
        
        self.writeHandler =  { (client: Socket & Writable, data: Data) throws -> () in
            if send(client.sockfd, data.bytes, data.length, 0) == -1 {
                throw SocketError.send("send: \(String.errno)")
            }
        }
        
        switch self.address! {
        case var .inet(addr):
            if connect(self.sockfd, pointer(of: &addr).cast(to: sockaddr.self), self.address!.socklen) == -1 {
                throw SocketError.connect(String.errno)
            }
        default: throw DNS.Error.unknownDomain
        }
    }
    
    public init(ipv6: String, service: String, type: SocketTypes = .stream, `protocol`: Int32 = 0, bufsize: Int = SXOutgoingSocket.defaultBufsize) throws {
        let port = (UInt16(getservbyname(service.cString(using: String.Encoding.ascii)!, nil).pointee.s_port)).byteSwapped
        self.sockfd = socket(AF_INET6, type.rawValue, `protocol`)
        self.domain = .inet6
        self.type = type
        self.protocol = `protocol`
        self.address = SXSocketAddress(address: ipv6, withDomain: .inet6, port: port)
        self.readBufsize = bufsize
        
        self.hashValue = Int(sockfd) * time(nil)
        
        self.readHandler = { client, size throws -> Data? in
            return client.isBlocking ?
                try client.recv_block(size: size) :
                try client.recv_nonblock(size: size)
        }
        
        self.writeHandler =  { (client: Socket & Writable, data: Data) throws -> () in
            if send(client.sockfd, data.bytes, data.length, 0) == -1 {
                throw SocketError.send("send: \(String.errno)")
            }
        }
        
        
        switch self.address! {
        case var .inet6(addr):
            if connect(self.sockfd, pointer(of: &addr).cast(to: sockaddr.self), self.address!.socklen) == -1 {
                throw SocketError.connect(String.errno)
            }
        default: throw DNS.Error.unknownDomain
        }
    }
}
