
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

#if os(OSX)
import Darwin
#elseif os(Linux)
import GLibc
#endif
import Foundation
import Dispatch

public protocol SXServerType : SXRuntimeObject, SXRuntimeController {
    var maxGuest: Int {get set}
    var port: in_port_t {get set}
    var socket: SXServerSocket {get set}
    var delegate: SXServerEventDelegate? {get set}
}

public protocol SXServer : SXServerType {
    var maxGuest: Int { get set }
    var socket: SXServerSocket { get set }
    var owner: SXRuntimeObject? { get set }
    var status: SXStatus { get set }
    var port: in_port_t { get set }
    var bufsize: Int { get set }
    var backlog: Int { get set }
    var delegate: SXServerEventDelegate? { get set }
    var method: SXRuntimeDataMethods { get set }
    
    #if swift(>=3)
    func start(listenQueue: (() -> DispatchQueue), operateQueue: (() -> DispatchQueue))
    #else
    func start(listenQueue: (() -> dispatch_queue_t), operateQueue: (() -> dispatch_queue_t))
    #endif
}

public class SXStreamServer: SXServerType {
    public var maxGuest: Int
    public var socket: SXServerSocket
    public var owner: SXRuntimeObject? = nil
    public var status: SXStatus
    public var port: in_port_t
    public var bufsize: Int
    public var backlog: Int
    public var delegate: SXServerEventDelegate?
    public var method: SXRuntimeDataMethods
    
    public var recvFlag: Int32 = 0
    public var sendFlag: Int32 = 0
    
    public func statusDidChange(status status: SXStatus) {
        self.delegate?.objectDidChangeStatus(object: self, status: status)
    }
    
    public func close() {
        self.socket.close()
    }
    
    public init(port: in_port_t, domain: SXSocketDomains, protocol: Int32 = 0, maxGuest: Int, backlog: Int, bufsize: Int = 16384, dataDelegate: SXRuntimeDataDelegate) throws {
        self.status = .IDLE
        self.socket = try SXServerSocket.init(port: port, domain: domain, type: .SOCK_STREAM, protocol: `protocol`, bufsize: bufsize)
        self.port = port
        self.backlog = backlog
        self.maxGuest = maxGuest
        self.bufsize = bufsize
        self.method = SXRuntimeDataMethods.delegate(dataDelegate)
    }
    
    
    public init(port: in_port_t, domain: SXSocketDomains, protocol: Int32 = 0, maxGuest: Int, backlog: Int, bufsize: Int = 16384, handler: (object: SXQueue, data: Data) -> Bool, errHandler: ((object: SXRuntimeObject, err: ErrorProtocol) -> ())? = nil) throws {
        self.status = .IDLE
        self.socket = try SXServerSocket.init(port: port, domain: domain, type: .SOCK_STREAM, protocol: `protocol`, bufsize: bufsize)
        self.port = port
        self.backlog = backlog
        self.maxGuest = maxGuest
        self.bufsize = bufsize
        let dd = SXRuntimeDataHandlerBlocks(didReceiveDataHandler: { (object, data) -> Bool in
            return handler(object: object as! SXQueue, data: data)
            }, didReceiveErrorHandler: errHandler)
        self.method = SXRuntimeDataMethods.block(dd)
    }
    
    #if swift(>=3)

    public func start() {
        self.start(listeningQueue: {DispatchQueue.global()}, operatingQueue: {DispatchQueue.global()})
    }
    
    public func start(listeningQueue: (() -> DispatchQueue), operatingQueue: (()->DispatchQueue)) {
        
        listeningQueue().async() {
            self.status = .RUNNING
            var count = 0
            do {
                while self.status != .SHOULD_TERMINATE {
                    
                    try self.socket.listen(backlog: self.backlog)
                    
                    if self.status == .SHOULD_TERMINATE {
                        break
                    } else if self.status == .SUSPENDED {
                        continue
                    }
                    
                    do {
                        
                        let socket = try SXRemoteStreamSocket(socket: try self.socket.accept(bufsize: self.bufsize))
                        if count >= self.maxGuest {
                            count += 1
                            continue
                        }
                        
                        if let handler = self.delegate?.serverShouldConnect(server: self, withSocket: socket) {
                            if !handler {
                                socket.close()
                                continue
                            }
                        }
                        
                        var queue: SXStreamQueue = SXStreamQueue(server: self, socket: socket, method: self.method)
                        
                        queue.delegate = self.delegate
                        
                        operatingQueue().async() {
                            queue.start(completion: {
                                queue.close()
                                queue.delegate?.objectDidDisconnect(object: queue, withSocket: queue.socket)
                                count -= 1
                            })
                        }
                        
                    } catch {
                        self.method.didReceiveError(object: self, err: error)
                        continue
                    }
                }
                
                self.status = .IDLE
                self.close()
                self.delegate?.serverDidKill(server: self)
                
            } catch {
                self.method.didReceiveError(object: self, err: error)
            }
        }
    }
    #else
    public func start(listenQueue: dispatch_queue_priority_t, operateQueue: dispatch_queue_priority_t) {
        self.start({dispatch_get_global_queue(listenQueue, 0)}, operatingQueue: {dispatch_get_global_queue(operateQueue, 0)})
    }
    
    public func start() {
        self.start(DISPATCH_QUEUE_PRIORITY_DEFAULT, operateQueue: DISPATCH_QUEUE_PRIORITY_DEFAULT)
    }
    
    
    public func start(listeningQueue: (() -> dispatch_queue_t), operatingQueue: (()->dispatch_queue_t)) {

        dispatch_async(listeningQueue()) {
            self.status = .RUNNING
            var count = 0
            do {
                while self.status != .SHOULD_TERMINATE {
                
                    try self.socket.listen(self.backlog)
                    
                    if self.status == .SHOULD_TERMINATE {
                        break
                    } else if self.status == .SUSPENDED {
                        continue
                    }

                    do {

                        let socket = try SXRemoteStreamSocket(socket: try self.socket.accept(bufsize: self.bufsize))
                        if count >= self.maxGuest {
                            count += 1
                            continue
                        }

                        if let handler = self.delegate?.serverShouldConnect(self, withSocket: socket) {
                            if !handler {
                                socket.close()
                                continue
                            }
                        }

                        var queue: SXStreamQueue = SXStreamQueue(server: self, socket: socket, method: self.method)
                        
                        queue.delegate = self.delegate
                        
                        dispatch_async(operatingQueue()) {
                            queue.start({
                                queue.close()
                                queue.delegate?.objectDidDisconnect(object: queue, withSocket: queue.socket)
                                count -= 1
                            })
                        }

                    } catch {
                        self.method.didReceiveError(object: self, err: error)
                        continue
                    }
                }
                
                self.status = .IDLE
                self.close()
                self.delegate?.serverDidKill(self)
                
            } catch {
                self.method.didReceiveError(object: self, err: error)
            }
        }
    }
    #endif
}
