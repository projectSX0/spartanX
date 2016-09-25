
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
//  Created by Yuji on 9/24/16.
//  Copyright © 2016 yuuji. All rights reserved.
//

#if os(OSX) || os(iOS) || os(watchOS) || os(tvOS)
    import typealias Darwin.in_port_t
#else
    import typealias Glibc.in_port_t
#endif

public struct SXSocketConfiguation {
    public var address: SXSocketAddress
    public var port: in_port_t
    
    public var domain: SocketDomains {
        return address.sockdomain()!
    }
    
    public var type: SocketTypes
    public var `protocol`: Int32
    public var backlog : Int
    
    /* legacy */
    public init(domain: SocketDomains = .unspec,
                type: SocketTypes = .stream,
                port: in_port_t,
                backlog: Int = 50,
                using `protocol`: Int32 = 0) {
        self.address = try! SXSocketAddress(withDomain: domain, port: port)
        self.type = type
        self.port = port
        self.backlog = backlog
        self.`protocol` = `protocol`
    }
    
    internal init(unixDomain: String, type: SocketTypes, backlog: Int = 50, using `protocol`: Int32 = 0) {
        self.address = SXSocketAddress(address: unixDomain, withDomain: .unix, port: 0)!
        self.port = 0
        self.backlog = backlog
        self.type = type
        self.`protocol` = `protocol`
    }
}
