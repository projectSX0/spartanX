
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

import Foundation

public class SXStreamQueue: SXQueue {
    
    
    public var status: SXStatus
    public var binded: [SXRuntimeObject] = []
    public var server: SXServer

    
    public var socket: SXSocket
    public var delegate: SXStreamRuntimeDelegate?
    
    public var recvFlag: Int32 = 0
    public var sendFlag: Int32 = 0
    
    public var dataDelegate: SXRuntimeDataDelegate
  
    init(server: SXStreamServer, socket: SXSocket) {
        
        self.recvFlag = server.recvFlag
        self.recvFlag = server.recvFlag
        
        self.socket = socket
        status = .idle
        self.server = server
        self.dataDelegate = server
        
    }
    
    public func statusDidChange(status: SXStatus) {
        self.status = status
    }
    
    public func retrieveData(with flags: Int32 = 0) throws -> Data? {
        let data = try self.socket.receive(size: self.socket.bufsize, flags: flags)
        if data.isEmpty {
            return nil
        }
        return data
    }
    
    public func close() {
        self.binded.removeAll()
        self.socket.close()
    }
    
}

public protocol SXQueue : SXRuntimeObject , SXRuntimeController {
    var server: SXServer {get set}
    
    var binded: [SXRuntimeObject] {get set}
    var status: SXStatus {get set}
    var recvFlag: Int32 { get set }
    var sendFlag: Int32 { get set }
    var dataDelegate: SXRuntimeDataDelegate {get set}

    func retrieveData(with flags: Int32) throws -> Data?

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
    
    public mutating func inherit(from server: SXServer) {
        if server.status != .running {
            self.status = server.status
        }
        
        if server.recvFlag != recvFlag {
            recvFlag = server.recvFlag
            self.recvFlag = recvFlag
        }
        
        if self.server.sendFlag != sendFlag {
            sendFlag = server.sendFlag
            self.sendFlag = sendFlag
        }
    }
    
    public mutating func start(completion: () -> ()) {
        self.status = .running
        
        var suspended = false;
        var proceed = false

        repeat {
            
            do {
                inherit(from: self.server)
                
                func handleData() throws {
                    if let data = try self.retrieveData(with: self.recvFlag) {
                        proceed = self.dataDelegate.didReceiveData(object: self, data: data)
                    } else {
                        proceed = false
                    }
                }
                
                switch self.status {
                    
                case .running:
                    try handleData()
                    
                case .resumming:
                    self.status = .running
                    self.statusDidChange(status: self.status)

                case .suspended:
                    if !suspended {
                        self.statusDidChange(status: self.status)
                    }
                    suspended = true

                    if let data = try retrieveData(with: 0) {
                        #if swift(>=3)
                        if (data.count == 0 || data.count == -1) { proceed = false }
                        #else
                        if (data.length == 0 || data.length == -1) { proceed = false }
                        #endif
                    } else {
                        proceed = false
                    }
                
                    switch self.status {
                        
                    case .shouldTerminate, .idle:
                        proceed = false
                        
                    case .running, .resumming:
                        try handleData()
                        
                    default:
                        break
                
                    }
                    
                case .shouldTerminate, .idle:
                    self.statusDidChange(status: self.status)
                }
                
            } catch {
                proceed = false
                self.dataDelegate.didReceiveError?(object: self, err: error)
            }
        } while (proceed)
        
        completion()
    }
}
