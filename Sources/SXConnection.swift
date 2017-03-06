
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

import xlibc
import struct Foundation.Data
import func Foundation.time

open class SXConnection: KqueueManagable, Writable, Hashable {
    
    public var ident: Int32
    public var readAgent: Readable
    public var writeAgent: Writable
    public var service: SXService
    public var supportedMethods: SendMethods = [.send, .sendfile, .sendmsg]
    
    public var userInfo = [String: Any]()
    
    public var hashValue: Int
    
    public var sectionToken: Int {
        return hashValue
    }
    
    public init(fd: Int32, readFrom r: Readable, writeTo w: Writable, with service: SXService) throws {
        self.readAgent = r
        self.writeAgent = w
        self.service = service
        self.ident = fd
        self.hashValue = Int(self.ident) * time(nil)
        SXKernelManager.default?.register(self)
    }
    
    public func done() {
        (service as? SXStreamService)?.connectionWillTerminate(self)
        self.readAgent.done()
        self.writeAgent.done()
        debugLog("connection of fd \(ident) is ended, \(#function): \(#file): \(#line)")
        SXKernelManager.default?.unregister(ident: ident, of: .read)
        (service as? SXStreamService)?.connectionDidTerminate(self)
    }

    public func write(data: Data) throws {
        return try self.writeAgent.write(data: data)
    }
   
    public func runloop(manager: SXKernel, _ ev: event) {
        
        do {
            #if os(OSX) || os(iOS) || os(watchOS) || os(tvOS) || os(FreeBSD) || os(PS4)
            let availableDataSize: Int = ev.data
            #elseif os(Linux) || os(Android)
            var availableDataSize: Int = 0
            _ = ioctl(ev.data.fd, UInt(FIONREAD), UnsafeMutableRawPointer(mutablePointer(of: &availableDataSize)))
            #endif

            if let data = try self.readAgent.read(size: availableDataSize) {
                
                if try !self.service.received(data: data, from: self) {
                    return done()
                }
            
            } else {
                return done()
            }
            
        } catch {
            if !self.service.exceptionRaised(error, on: self) {
                return done()
            }
        }
        
        #if os(OSX) || os(iOS) || os(watchOS) || os(tvOS) || os(FreeBSD) || os(PS4)
        manager.thread.exec {
            manager.register(self)
        }
        #endif
    }
}

public func ==(lhs: SXConnection, rhs: SXConnection) -> Bool {
    return lhs.hashValue == rhs.hashValue
}
