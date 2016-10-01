
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

#if os(OSX) || os(iOS) || os(watchOS) || os(tvOS)
import Darwin
#else
import Glibc
#endif

import struct Foundation.Data

public protocol UNIXFileDescriptor {
    var fileDescriptor: Int32 { get }
}

public protocol Readable {
//    var readBufsize: size_t { get set }
    func read(size: Int) throws -> Data?
    func done()
}

public protocol Writable {
    func write(data: Data) throws
    func done()
}

extension UNIXFileDescriptor where Self : Readable {
    func read_block(size: Int) throws -> Data? {
//        let size = self.readBufsize
        
        var buffer = [UInt8](repeating: 0, count: size)
        var len = 0
        
        #if os(OSX) || os(iOS) || os(watchOS) || os(tvOS)
        len = Darwin.read(self.fileDescriptor, &buffer, size)
        #else
        len = Glibc.read(self.fileDescriptor, &buffer, size)
        #endif
        
        if len == 0 {
            return nil
        }
        
        if len == -1 {
            throw SocketError.recv(String.errno)
        }
        
        return Data(bytes: buffer, count: len)
    }
    
    func read_nonblock(size: Int) throws -> Data? {
//        let size = self.readBufsize
        
        var buffer = [UInt8](repeating: 0, count: size)
        var len = 0
        var _len = 0
        recv_loop: while true {
            var smallbuffer = [UInt8](repeating: 0, count: size)
        
            #if os(OSX) || os(iOS) || os(watchOS) || os(tvOS)
            len = Darwin.read(self.fileDescriptor, &smallbuffer, size)
            #else
            len = Glibc.read(self.fileDescriptor, &smallbuffer, size)
            #endif
        
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

