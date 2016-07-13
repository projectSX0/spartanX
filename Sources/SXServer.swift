
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

public protocol SXServer : SXRuntimeObject, SXRuntimeController {
    var maxGuest: Int { get set }
    var socket: SXServerSocket { get set }
   
    var port: in_port_t { get set }
    var bufsize: Int { get set }
    var backlog: Int { get set }
    
    #if swift(>=3)
    func start(listenQueue: (() -> DispatchQueue), operateQueue: (() -> DispatchQueue))
    #else
    func start(listenQueue: (() -> dispatch_queue_t), operateQueue: (() -> dispatch_queue_t))
    #endif
}


public class SXStreamServer: SXServer, SXRuntimeDataDelegate {
    public var maxGuest: Int
    public var socket: SXServerSocket
   
    public var owner: AnyObject? = nil
    public var status: SXStatus
    public var port: in_port_t
    public var bufsize: Int
    public var backlog: Int

    public var delegate: SXStreamServerDelegate?

    public var didReceiveData: (object: SXQueue, data: Data) -> Bool
    public var didReceiveError: ((object: SXRuntimeObject, err: ErrorProtocol) -> ())?
    
    public var recvFlag: Int32 = 0
    public var sendFlag: Int32 = 0
    
    public func statusDidChange(status: SXStatus) {
        guard let delegate = self.delegate else {return}
        delegate.didChangeStatus?(object: self, status: status)
    }
    
    public func close() {
        self.delegate?.didKill?(server: self)
        self.socket.close()
    }
    
    init(port: in_port_t, domain: SXSocketDomains, protocol: Int32 = 0, maxGuest: Int, backlog: Int, bufsize: Int = 16384, dataDelegate: SXRuntimeDataDelegate) throws {
        self.status = .idle
        self.socket = try SXServerSocket.init(port: port, domain: domain, type: .stream, protocol: `protocol`, bufsize: bufsize)
        self.port = port
        self.backlog = backlog
        self.maxGuest = maxGuest
        self.bufsize = bufsize
        self.didReceiveData = dataDelegate.didReceiveData
        self.didReceiveError = dataDelegate.didReceiveError
    }
    
    
    public init(port: in_port_t, domain: SXSocketDomains, protocol: Int32 = 0, maxGuest: Int, backlog: Int, bufsize: Int = 16384, handler: (object: SXQueue, data: Data) -> Bool, errHandler: ((object: SXRuntimeObject, err: ErrorProtocol) -> ())? = nil) throws {
        self.status = .idle
        self.socket = try SXServerSocket.init(port: port, domain: domain, type: .stream, protocol: `protocol`, bufsize: bufsize)
        self.port = port
        self.backlog = backlog
        self.maxGuest = maxGuest
        self.bufsize = bufsize
        self.didReceiveData = handler
    }
    
    #if swift(>=3)

    public func start() {
        self.start(listenQueue: {DispatchQueue.global()}, operateQueue: {DispatchQueue.global()})
    }
    
    public func start(listenQueue listeningQueue: (() -> DispatchQueue), operateQueue operatingQueue: (()->DispatchQueue)) {
        
        listeningQueue().async() {
            self.status = .running
            var count = 0
            do {
                while self.status != .shouldTerminate {
                    
                    try self.socket.listen(backlog: self.backlog)
                    
                    if self.status == .shouldTerminate {
                        break
                    } else if self.status == .suspended {
                        continue
                    }
                    
                    do {
                        
                        let socket = try SXRemoteStreamSocket(socket: try self.socket.accept(bufsize: self.bufsize))
                        if count >= self.maxGuest {
                            count += 1
                            continue
                        }
                        
                        if let handler = self.delegate?.shouldConnect?(server: self, withSocket: socket) {
                            if !handler {
                                socket.close()
                                continue
                            }
                        }
                        
                        var queue: SXStreamQueue = SXStreamQueue(server: self, socket: socket)
                        
                        if self.delegate != nil {
                            transfer(lhs: &queue.delegate!, rhs: &self.delegate!)
                        }
                        
                        operatingQueue().async() {
                            queue.start(completion: {
                                queue.close()
                                queue.delegate?.didDisconnect?(object: queue, withSocket: queue.socket)
                                count -= 1
                            })
                        }
                        
                    } catch {
                        self.didReceiveError?(object: self, err: error)
                        continue
                    }
                }
                
                self.status = .idle
                self.close()
                self.delegate?.didKill?(server: self)
            } catch {
                self.didReceiveError?(object: self, err: error)
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
            self.status = .running
            var count = 0
            do {
                while self.status != .shouldTerminate {
                
                    try self.socket.listen(self.backlog)
                    
                    if self.status == .shouldTerminate {
                        break
                    } else if self.status == .suspended {
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
                                queue.delegate?.didDisconnect(queue, withSocket: queue.socket)
                                count -= 1
                            })
                        }

                    } catch {
                        self.didReceiveError?(self, err: error)
                        continue
                    }
                }
                
                self.status = .idle
                self.close()
                self.delegate?.didKill?(self)
                
            } catch {
                self.didReceiveError?(self, err: error)
            }
        }
    }
    #endif
}
