
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
//  Created by Yuji on 6/3/16.
//  Copyright © 2016 yuuji. All rights reserved.
//

import Foundation

public enum SXStatus {
    case idle
    case running
    case resumming
    case suspended
    case shouldTerminate
}

public protocol SXRuntimeObject {
    
    var status: SXStatus { get }

    func statusDidChange(status: SXStatus)
    
    func close()
}

public protocol SXRuntimeController {
    var recvFlag: Int32 {get set}
    var sendFlag: Int32 {get set}
}

public protocol SXRuntimeBasicDelegate {
    var didChangeStatus: ((_ object: SXRuntimeObject, _ status: SXStatus) -> ())? {get set}
}

public protocol SXRuntimeDataDelegate {
    var didReceiveData: (_ object: SXQueue, _ data: Data) -> Bool {get set}
    var didReceiveError: ((_ object: SXRuntimeObject, _ err: Error) -> ())? {get set}
}

public protocol SXStreamRuntimeDelegate {
    var didConnect: ((_ object: SXRuntimeObject, _ withSocket: SXSocket) -> ())? {get set}
    var didDisconnect: ((_ object: SXRuntimeObject, _ withSocket: SXSocket) -> ())? {get set}
    var willKill: ((_ object: SXRuntimeObject) -> ())? {get set}
}


public protocol SXServerDelegate: SXRuntimeBasicDelegate {
    var shouldConnect: ((_ server: SXServer, _ withSocket: SXSocket) -> Bool)? {get set}
    var didStart: ((_ server: SXServer) -> ())? {get set}
    var didKill: ((_ server: SXServer) -> ())? {get set}
}

public protocol SXStreamServerDelegate : SXServerDelegate, SXStreamRuntimeDelegate {
}


internal func transfer (lhs: inout SXStreamRuntimeDelegate, rhs: inout SXStreamServerDelegate) {
    lhs.didConnect = rhs.didConnect
    lhs.didDisconnect = rhs.didDisconnect
    lhs.willKill = rhs.willKill
}

