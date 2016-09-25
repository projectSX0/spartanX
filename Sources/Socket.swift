
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

import struct Foundation.Data

#if os(OSX) || os(iOS) || os(watchOS) || os(tvOS)
import Darwin
#else
import Glibc
#endif

public protocol Socket : UNIXFileDescriptor {
    var sockfd: Int32 { get }
    var domain: SocketDomains { get set }
    var type: SocketTypes { get set }
    var `protocol`: Int32 { get set }
}

public protocol ServerSocket : Socket, Addressable {
    func accept() throws -> ClientSocket
}

public protocol ClientSocket : Socket, Readable, Writable {
    /* storing address */
    var address: SXSocketAddress? { get set }
}

public protocol ConnectionSocket : Socket, Addressable, Readable, Writable {
    
}

extension Socket {
    
    public var fileDescriptor: Int32 {
        return self.sockfd
    }
    
    internal func setBlockingMode(block: Bool) {
        let sockflags = fcntl(self.sockfd, F_GETFL, 0)
        _ = fcntl(self.sockfd, F_SETFL, block ? sockflags ^ O_NONBLOCK : sockflags | O_NONBLOCK)
    }
    
    public func setTimeoutInterval(_ time: timeval) {
        var time = time
        setsockopt(sockfd, SOL_SOCKET, SO_RCVTIMEO, &time, socklen_t(MemoryLayout<timeval>.size))
    }
    
    public var isBlocking: Bool {
        return ((fcntl(self.sockfd, F_GETFL, 0) & O_NONBLOCK) == 0)
    }
}

extension Readable where Self : Socket {
    func recv_block(r_flags: Int32 = 0) throws -> Data? {
        let size = self.readBufsize
        
        var buffer = [UInt8](repeating: 0, count: size)
        var len = 0
        
        len = recv(self.sockfd, &buffer, size, r_flags)
        
        if len == 0 {
            return nil
        }
        
        if len == -1 {
            throw SocketError.recv(String.errno)
        }
        
        return Data(bytes: buffer, count: len)
    }
    
    func recv_nonblock(r_flags: Int32 = 0) throws -> Data? {
        let size = self.readBufsize
        
        var buffer = [UInt8](repeating: 0, count: size)
        var len = 0
        var _len = 0
        recv_loop: while true {
            var smallbuffer = [UInt8](repeating: 0, count: size)
            len = recv(sockfd, &smallbuffer, size, r_flags)
            
            if len < 0 {
                
                switch errno {
                case EAGAIN, EWOULDBLOCK:
                    break recv_loop
                default:
                    throw SocketError.recv(String.errno)
                }
                
            } else if len > 0 {
                buffer.append(contentsOf: smallbuffer)
                _len += len
            } else {
                return nil
            }
        }
        
        return Data(bytes: buffer, count: len)
    }
}

extension KqueueManagable where Self : Socket {
    public var ident: Int32 {
        return sockfd
    }
}
