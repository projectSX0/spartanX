
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
//  Created by yuuji on 9/5/16.
//  Copyright © 2016 yuuji. All rights reserved.
//


import struct Foundation.Data

public typealias ShouldProceed = Bool

public let YES = true
public let NO = false


/// a SXService is a protocol to define a service that can use in spartanX
public protocol SXService {
    // this is here to support low-level optimization, for example, if we are sending pure http content with
    // static files, it is much less expensive to use sendfile() instead of send(), since it can implement by
    // both sendfile() and send(), the supportingMethods should include both.
    // when the service is nested in another service, for example TLS, sendfile is no longer available
    // but send() is still available, this supporting method here hints what kind of optimazation is available
    // in the end
    var supportingMethods: SendMethods { get set }
    
    /// What to do when a package is received
    ///
    /// - Parameters:
    ///   - data: The payload received
    ///   - connection: in which connection
    /// - Returns: depends on the payload, should the server retain this connection(true) or disconnect(false)
    /// - Throws: Raise an exception and handle with exceptionRaised()
    func received(data: Data, from connection: SXConnection) throws -> ShouldProceed
    
    
    /// Handle Raised exceptions raised in received()
    ///
    /// - Parameters:
    ///   - exception: Which exception raised
    ///   - connection: in which connection
    /// - Returns: should the server retain this connection(true) or disconnect(false)
    func exceptionRaised(_ exception: Error, on connection: SXConnection) -> ShouldProceed
}


/// a SXStreamService is smaliar to SXService that slightly powerful but can only use on stream connections
/// a SXSrreamService can perform actions when a new connection is accepted, when a connection is going to
/// terminate, and when a connection has terminated
public protocol SXStreamService : SXService {
    func accepted(socket: SXClientSocket, as connection: SXConnection) throws
    func connectionWillTerminate(_ connection: SXConnection)
    func connectionDidTerminate(_ connection: SXConnection)
}



/// a simple data transfer service
open class SXConnectionService: SXService {
    
    open func exceptionRaised(_ exception: Error, on connection: SXConnection) -> ShouldProceed {
        return false
    }

    open var supportingMethods: SendMethods = [.send, .sendfile, .sendto]
    
    open func received(data: Data, from connection: SXConnection) throws -> ShouldProceed {
        return try self.dataHandler(data, connection)
    }
    
    open var dataHandler: (Data, SXConnection) throws -> ShouldProceed
    
    public init(handler: @escaping (Data, SXConnection) throws -> ShouldProceed) {
        self.dataHandler = handler
    }
}



