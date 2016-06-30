
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

import Darwin
import Foundation

public class SXStreamQueue: SXQueue {
    
    
    public var status: SXStatus
    public var binded: [SXRuntimeObject] = []
    public var server: SXServerType
    public var method: SXRuntimeDataMethods
    public var delegate: SXRuntimeStreamObjectDelegate?
    
    public var socket: SXRemoteStreamSocket
    
    public var recvFlag: Int32 = 0
    public var sendFlag: Int32 = 0
    
    public init(server: SXStreamServer, socket: SXRemoteStreamSocket, handler: (object: SXQueue, data: Data) -> Bool, errHandler: ((object: SXRuntimeObject, err: ErrorProtocol) -> ())?) {
        
        self.recvFlag = server.recvFlag
        self.recvFlag = server.recvFlag
        
        self.socket = socket
        status = .IDLE
        self.server = server
        self.method = .block(SXRuntimeDataHandlerBlocks(didReceiveDataHandler: {handler(object: $0 as! SXQueue, data: $1)}, didReceiveErrorHandler: errHandler))
    }
    
    public init(server: SXStreamServer, socket: SXRemoteStreamSocket, delegate: SXRuntimeDataDelegate) {
        
        self.recvFlag = server.recvFlag
        self.recvFlag = server.recvFlag
        
        self.socket = socket
        status = .IDLE
        self.server = server
        self.method = .delegate(delegate)
    }
    
    public func setDataDelegate(delegate delegate: SXRuntimeDataDelegate) {
        self.method = .delegate(delegate)
    }
    
    init(server: SXStreamServer, socket: SXRemoteStreamSocket, method: SXRuntimeDataMethods) {
        
        self.recvFlag = server.recvFlag
        self.recvFlag = server.recvFlag
        
        self.socket = socket
        status = .IDLE
        self.server = server
        self.method = method
    }
    
    public func statusDidChange(status status: SXStatus) {
        self.status = status
    }
    
    public func getData(flags flags: Int32 = 0) throws -> Data {
        return try self.socket.receive(size: self.socket.bufsize, flags: flags)
    }
    
    public func close() {
        self.binded.removeAll()
        self.socket.close()
    }
}

public protocol SXQueue : SXRuntimeObject , SXRuntimeController {
    var server: SXServerType {get set}
    var binded: [SXRuntimeObject] {get set}
    var method: SXRuntimeDataMethods {get set}
    var delegate: SXRuntimeStreamObjectDelegate? {get set}
    func getData(flags flags: Int32) throws -> Data
    #if swift(>=3)
    mutating func bind(obj: inout SXRuntimeObject)
    #else
    mutating func bind(inout obj obj: SXRuntimeObject)
    #endif
    mutating func start(completion: () -> ())
}

extension SXQueue {
    
    public var owner: SXRuntimeObject? {
            get {
                return server
            } set {
                if let s = newValue as? SXServer {
                    server = s
                }
            }
        }
    
    public mutating func start(completion: () -> ()) {
        self.status = .RUNNING
        
        var suspended = false;
        var s = 0
        
        var cacheRecv = self.server.recvFlag
        var cacheSend = self.server.sendFlag
        
        repeat {
            
            if self.server.status != .RUNNING {
                self.status = self.server.status
            }
            
            if self.server.recvFlag != cacheRecv {
                cacheRecv = server.recvFlag
                self.recvFlag = cacheRecv
            }
            
            if self.server.sendFlag != cacheSend {
                cacheSend = server.sendFlag
                self.sendFlag = cacheSend
            }
            
            func handleData() {
                do {
                    let data = try self.getData(flags: self.recvFlag)
                    let proceed = self.method.didReceiveData(object: self, data: data)
                    s = proceed ? data.length : 0
                } catch {
                    s = 0
                    self.method.didReceiveError(object: self, err: error)
                }
            }
            
            switch self.status {
            case .RUNNING:
                
                handleData()
                
            case .RESUMMING:
                self.status = .RUNNING
                self.statusDidChange(status: self.status)
                
            case .SUSPENDED:
                if !suspended {
                    self.statusDidChange(status: self.status)
                }
                suspended = true
                
                do {
                    let data = try getData(flags: 0)
                    #if swift(>=3)
                    if (data.count == 0 || data.count == -1) { s = 0 }
                    #else
                    if (data.length == 0 || data.length == -1) { s = 0 }
                    #endif
                } catch {
                    s = 0
                    self.method.didReceiveError(object: self, err: error)
                }
            
                switch self.status {
                case .SHOULD_TERMINATE, .IDLE:
                    s = 0
                case .RUNNING, .RESUMMING: handleData()
                default: break
                }
            case .SHOULD_TERMINATE, .IDLE:
                
                self.delegate?.objectWillKill(object: self)
                self.statusDidChange(status: self.status)
            }
            
        } while (s > 0)
        
        completion()
    }
    
    #if swift(>=3)
    public mutating func bind(obj obj: inout SXRuntimeObject) {
        self.binded.append(obj)
        obj.owner = self
    }
    #else
    public mutating func bind(inout obj obj: SXRuntimeObject) {
        self.binded.append(obj)
        obj.owner = self
    }
    #endif
}
