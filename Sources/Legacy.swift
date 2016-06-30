//
//  Legacy.swift
//  spartanX
//
//  Created by yuuji on 6/18/16.
//  Copyright © 2016 yuuji. All rights reserved.
//

import Foundation
#if !swift(>=3)
    
    extension UnsafeMutablePointer {
        var pointee: Memory {
            get {
                return self.memory
            } set {
                self.memory = newValue
            }
        }
    }
    
    public typealias ErrorProtocol = ErrorType
    public typealias Data = NSMutableData

    public extension Data {
        
        public var count: Int {
            return self.length
        }
        public func findBytes(bytes b: UnsafeMutablePointer<Void>, offset: Int = 0, len: Int) -> Int? {
            if offset < 0 || len < 0 || self.length == 0 || len + offset > self.length
            { return nil }
            
            var i = 0
            let mcmp = {memcmp(b, self.bytes.advancedBy(offset + i), len)}
            
            
            while (mcmp() != 0) {
                if i + offset == self.length {
                    break
                }
                i += 1
            }
            
            return i + offset
        }
    }
    
    public struct NSDataSegment {
        public var core: Data
        public var curOffset: Int = 0
        private var nextOffset: Int = 0
        private var curlen = 0
        
        public var curVal: Data {
            get {
                return core.subdataWithRange(NSMakeRange(curOffset, curlen)).mutableCopy() as! NSMutableData
            }
        }
        
        public var sepearator: [UInt8]
        
        public mutating func next() -> Data? {
            if let endpoint = core.findBytes(bytes: &sepearator, offset: nextOffset, len: sepearator.count) {
                curlen = endpoint - nextOffset
                curOffset = nextOffset
                nextOffset = sepearator.count + endpoint
                return curVal
            }
            return nil
        }
        
        public mutating func findall(handler: (NSData) -> Bool) {
            while next() != nil {
                if !handler(curVal) {
                    break
                }
            }
        }
        
        public init(core: NSData, sepearatorBytes: [UInt8]) {
            self.core = core as! NSMutableData
            self.sepearator = sepearatorBytes
        }
    }
    public struct DataReader {
        public var origin: Data
        public var currentOffset: Int = 0
        
        init(fromData data: Data) {
            self.origin = data
        }
    }
    
    extension DataReader {
        
        public mutating func rangeOfNextSegmentOfData(separatedBy bytes: [UInt8]) -> NSRange? {
            var bytes = bytes
            return rangeOfNextSegmentOfData(separatedBy: &bytes)
        }
        public mutating func rangeOfNextSegmentOfData(inout separatedBy bytes: [UInt8]) -> NSRange? {
            guard let endpoint = origin.findBytes(bytes: &bytes,
                                                  offset: currentOffset,
                                                  len: bytes.count) else {
                                                    return nil
            }
            let begin = currentOffset
            let length = endpoint - currentOffset
            currentOffset = endpoint + bytes.count
            return NSMakeRange(begin, length)
        }
    }
    extension DataReader {
        
        public mutating func segmentOfData(separatedBy bytes: [UInt8], atIndex count: Int) -> Data? {
            var bytes = bytes
            return segmentOfData(separatedBy: &bytes, atIndex: count)
        }
        
        public mutating func segmentOfData(inout separatedBy bytes: [UInt8], atIndex count: Int) -> Data? {
            var holder: NSRange?
            var i = 0
            
            repeat {
                holder = rangeOfNextSegmentOfData(separatedBy: &bytes)
                i += 1
            } while i <= count && holder != nil
            
            if holder == nil {
                return nil
            }
            return origin.subdataWithRange(holder!).mutableCopy() as? Data
        }
    }
    
    extension DataReader {
        
        public mutating func nextSegmentOfData(separatedBy bytes: [UInt8]) -> Data? {
            var bytes = bytes
            return nextSegmentOfData(separatedBy: &bytes)
        }
        
        public mutating func nextSegmentOfData(inout separatedBy bytes: [UInt8]) -> Data? {
            if let range = rangeOfNextSegmentOfData(separatedBy: &bytes) {
                return origin.subdataWithRange(range).mutableCopy() as? Data
            }
            return nil
        }
    }
    
    extension DataReader {
        
        public mutating func forallSegments(separatedBy bytes: [UInt8], handler: (Data) -> Bool) {
            var bytes = bytes
            return forallSegments(separatedBy: &bytes, handler: handler)
        }
        
        public mutating func forallSegments(inout separatedBy bytes: [UInt8], handler: (Data) -> Bool) {
            var data = nextSegmentOfData(separatedBy: &bytes)
            while data != nil {
                if !handler(data!) {
                    break
                }
                data = nextSegmentOfData(separatedBy: &bytes)
            }
        }
        
    }
    
    extension String {
        var cInt8String: [Int8]? {
            get {
                guard let uint8string = self.cStringUsingEncoding(NSASCIIStringEncoding) else {return nil}
                return uint8string.map({Int8($0)})
            }
        }
        
        func cString(using encoding: StringEncoding) -> [CChar] {
            return self.cStringUsingEncoding(encoding.raw)!
        }
    }
    
    public enum StringEncoding {
        case ascii
        case utf8
        case utf16
        
        var raw: NSStringEncoding {
            switch self {
            case .utf8: return NSUTF8StringEncoding
            case .utf16: return NSUTF16StringEncoding
            default: return NSASCIIStringEncoding
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
        
        init?(data: Data, encoding: StringEncoding) {
            print(data)
            if let buf = String(data: data, encoding: encoding.raw) {
                self = buf
            } else {
                return nil
            }
        }
        
        func data(using encoding: StringEncoding) -> Data? {
            return self.dataUsingEncoding(encoding.raw)! as? NSMutableData
        }
        
        static var errno: String {
            let err = strerror(Darwin.errno)
            return String(bytes: err, len: Int(strlen(err)))
        }
    }
    
    
    func getpointer<T>(inout obj: T) -> UnsafePointer<T> {
        let ghost: (UnsafePointer<T>) -> UnsafePointer<T> = {$0}
        return withUnsafePointer(&obj, {ghost($0)})
    }
    
    func getMutablePointer<T>(inout obj: T) -> UnsafeMutablePointer<T> {
        let ghost: (UnsafeMutablePointer<T>) -> UnsafeMutablePointer<T> = {$0}
        return withUnsafeMutablePointer(&obj, {ghost($0)})
    }
#endif
