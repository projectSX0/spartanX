
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

//public protocol SXService {
//    var dataHandler: (SXQueue, Data) -> Bool { get set }
//    var errHandler: ((SXQueue, Error) -> ())? { get set }
//}

public protocol SXService {
    static var supportedMethods: SendMethods { get set }
    var dataHandler: (SXQueue, Data) throws -> Bool  { get set }
    var errHandler: ((SXQueue, Error) -> ())? { get set }
}

public protocol SXStreamSocketService : SXService {
    var acceptedHandler: ((inout SXClientSocket) -> ())? { get set }
}

open class SXConnectionService: SXService {
    open var dataHandler: (SXQueue, Data) throws -> Bool
    open var errHandler: ((SXQueue, Error) -> ())?
    open var willTerminateHandler: ((SXQueue) -> ())?
    open var didTerminateHandler: ((SXQueue) -> ())?
    open static var supportedMethods: SendMethods = SendMethods(rawValue: 0)
    public init(handler: @escaping (SXQueue, Data) throws -> Bool) {
        self.dataHandler = handler
    }
}



