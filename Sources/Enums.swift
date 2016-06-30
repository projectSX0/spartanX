
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

public enum SXSocketError: ErrorProtocol {
    case nonImplementedDomain
    case socket(String)
    case setSockOpt(String)
    case bind(String)
    case connect(String)
    case recv(String)
    case listen(String)
}

public enum SXAddrError: ErrorProtocol {
    case getAddrInfo(String)
    case unknownDomain
}

public enum SXSocketDomains: UInt8 {
    case UNSPEC     = 0
    case UNIX       = 1
    case INET       = 2
    case IMPLINK    = 3
    case PUP        = 4
    case CHAOS      = 5
    case BS         = 6
    case ISO        = 7
    case ECMA       = 8
    case DATAKIT    = 9
    case CCITT      = 10
    case SNA        = 11
    case DECnet     = 12
    case DLI        = 13
    case LAT        = 14
    case HYLINK     = 15
    case APPLETALK  = 16
    case ROUTE      = 17
    case LINK       = 18
    case pseudo_AF_XTP = 19
    case COIP       = 20
    case CNT        = 21
    case pseudo_AF_RTIP = 22
    case IPX        = 23
    case SIP        = 24
    case pseudo_AF_PIP = 25
    case NDRV       = 27
    case ISDN       = 28
    case pseudo_AF_KEY = 29
    case INET6      = 30
    case NATM       = 31
    case SYSTEM     = 32
    case NETBIOS    = 33
    case PPP        = 34
    case pseudo_AF_HDRCMPLT = 35
    case RESERVED_36 = 36
    case IEEE80211  = 37
    case UTUN       = 38
    case MAX        = 40
}

public enum SXSocketTypes: Int32 {
    case SOCK_STREAM    = 1
    case SOCK_DGRAM     = 2
    case SOCK_RAW       = 3
    case SOCK_RDM       = 4
    case SOCK_SEQPACKET = 5
}
