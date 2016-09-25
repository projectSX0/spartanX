
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

#if __tls
import swiftTLS
import struct Foundation.Data

public struct SXTLSContextInfo {
    public var certificate: (path: String, passwd: String?)
    public var privateKey: (path: String, passwd: String?)
    public var ca: (path: String, passwd: String?)?
    public var ca_path: String?
    
    public init(certificate: (path: String, passwd: String?),
                privateKey: (path: String, passwd: String?),
                ca: (path: String, passwd: String?)? = nil,
                ca_path: String? = nil) {
        self.certificate = certificate
        self.privateKey = privateKey
        self.ca = ca
        self.ca_path = ca_path
    }
}

public class SXTLSLayer :  SXStreamSocketService {
    
    public var context: TLSServer
    public var dataHandler: (SXQueue, Data) -> Bool
    public var errHandler: ((SXQueue, Error) -> ())?
    public var acceptedHandler: ((inout SXClientSocket) -> ())?
    
    public var clientsMap = [Int32: TLSClient]()
    
    public init(service: SXService, tls: SXTLSContextInfo) throws {
        var config: TLSConfig!
        
        if let ca_path = tls.ca_path {
            config = try TLSConfig(ca_path: ca_path,
                                    cert: tls.certificate.path,
                                    cert_passwd: tls.certificate.passwd,
                                    key: tls.certificate.path,
                                    key_passwd: tls.certificate.passwd)
        } else if let ca = tls.ca {
            config = try TLSConfig(ca: ca.path,
                                   ca_passwd: ca.passwd,
                                   cert: tls.certificate.path,
                                   cert_passwd: tls.certificate.passwd,
                                   key: tls.certificate.path,
                                   key_passwd: tls.certificate.passwd)
        } else {
            config = try TLSConfig(cert: tls.certificate.path,
                                   cert_passwd: tls.certificate.passwd,
                                   key: tls.certificate.path,
                                   key_passwd: tls.certificate.passwd)
        }
        
        self.context = try TLSServer(with: config)
        
        self.dataHandler = service.dataHandler
        self.errHandler = { queue, error in
            switch error {
            case TLSError.filedescriptorNotWriteable, TLSError.filedescriptorNotReadable:
                break
            default:
                service.errHandler?(queue, error)
            }
        }
        
        self.acceptedHandler = { client in
            do {
                self.clientsMap[client.sockfd] = try self.context.accept(socket: client.sockfd)
                client._read = { client_socket throws -> Data? in
                    return try self.clientsMap[client_socket.sockfd]?.read(size: 16 * 1024)
                }
                
                client._write = { client_socket, data throws in
                    _ = try self.clientsMap[client_socket.sockfd]?.write(data: data)
                }
            } catch {
                
            }
        }
    }
}
#endif
