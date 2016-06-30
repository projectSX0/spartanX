
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

#if swift(>=3)
    public extension Data {
        public func findBytes(bytes b: UnsafeMutablePointer<Void>, offset: Int = 0, len: Int) -> Int? {
            if offset < 0 || len < 0 || self.count == 0 || len + offset > self.count
            { return nil }
            
            var i = 0
        
            let mcmp = {memcmp(b,(self as NSData).bytes.advanced(by: offset + i), len)}
            
            while (mcmp() != 0) {
                if i + offset == self.count {
                    break
                }
                i += 1
            }
            
            return i + offset
        }
    }
    
    extension String {
        var cInt8String: [Int8]? {
            get {
                guard let uint8string = self.cString(using: String.Encoding.ascii) else {return nil}
                return uint8string.map({Int8($0)})
            }
        }
    }
    
    extension String {
        init (bytes: UnsafeMutablePointer<UInt8>, len: size_t) {
            self = String((0..<len).map({Character(UnicodeScalar(bytes[$0]))}))
        }
        init (bytes: UnsafeMutablePointer<Int8>, len: size_t) {
            self = String((0..<len).map({Character(UnicodeScalar(UInt8(bytes[$0])))}))
        }
        
        static var errno: String {
            let err = strerror(Darwin.errno)
            return String(bytes: err!, len: Int(strlen(err)))
        }
    }
    
    
    func getpointer<T>(_ obj: inout T) -> UnsafePointer<T> {
        let ghost: (UnsafePointer<T>) -> UnsafePointer<T> = {$0}
        return withUnsafePointer(&obj, {ghost($0)})
    }
    
    func getMutablePointer<T>(_ obj: inout T) -> UnsafeMutablePointer<T> {
        let ghost: (UnsafeMutablePointer<T>) -> UnsafeMutablePointer<T> = {$0}
        return withUnsafeMutablePointer(&obj, {ghost($0)})
    }
#endif
