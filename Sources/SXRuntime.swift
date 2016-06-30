
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
    case IDLE
    case RUNNING
    case RESUMMING
    case SUSPENDED
    case SHOULD_TERMINATE
}

public protocol SXRuntimeObject {
    var status: SXStatus {get set}
    var owner: SXRuntimeObject? {get set}
    
    func statusDidChange(status status: SXStatus)
    func close()
}

public protocol SXRuntimeController {
    var method: SXRuntimeDataMethods {get set}
    var recvFlag: Int32 {get set}
    var sendFlag: Int32 {get set}
}

public protocol SXServerEventDelegate : SXRuntimeStreamObjectDelegate {
    func serverShouldConnect(server: SXServerType, withSocket socket: SXRemoteSocket) -> Bool
    func serverDidStart(server: SXServerType)
    func serverDidKill(server: SXServerType)
}

public protocol SXRuntimeDataDelegate {
    func didReceiveData(object object: SXRuntimeObject, data: Data) -> Bool
    func didReceiveError(object object: SXRuntimeObject, err: ErrorProtocol)
}

public protocol SXRuntimeStreamObjectDelegate : SXRuntimeObjectDelegate {
    func objectDidConnect(object object: SXRuntimeObject, withSocket: SXRemoteSocket)
    func objectDidDisconnect(object object: SXRuntimeObject, withSocket: SXRemoteSocket)
    func objectWillKill(object object: SXRuntimeObject)
}

public protocol SXRuntimeObjectDelegate {
    func objectDidChangeStatus(object object: SXRuntimeObject, status: SXStatus)
}

public struct SXRuntimeDataHandlerBlocks {
    var didReceiveDataHandler: ((object: SXRuntimeObject, data: Data) -> Bool)
    var didReceiveErrorHandler: ((object: SXRuntimeObject, err: ErrorProtocol) -> ())?
}

public enum SXRuntimeDataMethods {
    case delegate(SXRuntimeDataDelegate)
    case block(SXRuntimeDataHandlerBlocks)
    
    func didReceiveData(object object: SXRuntimeObject, data: Data) -> Bool {
        switch self {
        case let .delegate(delegate):
            return delegate.didReceiveData(object: object, data: data)
        case let .block(block):
            return block.didReceiveDataHandler(object: object, data: data)
        }
    }
    
    func didReceiveError(object object: SXRuntimeObject, err: ErrorProtocol) {
        switch self {
        case let .delegate(delegate):
            delegate.didReceiveError(object: object, err: err)
        case let .block(block):
            block.didReceiveErrorHandler?(object: object, err: err)
        }
    }
}
