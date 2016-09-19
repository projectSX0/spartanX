//
//  FileEvents.swift
//  spartanX
//
//  Created by yuuji on 9/18/16.
//
//

import Foundation

extension SXKernel {
    public struct FileEvents: OptionSet {
        static let deleted = FileEvents(rawValue: UInt32(NOTE_DELETE))
        static let written = FileEvents(rawValue: UInt32(NOTE_WRITE))
        static let sizeChanged = FileEvents(rawValue: UInt32(NOTE_EXTEND))
        static let permissionChanged = FileEvents(rawValue: UInt32(NOTE_ATTRIB))
        static let linked = FileEvents(rawValue: UInt32(NOTE_LINK))
        static let renamed = FileEvents(rawValue: UInt32(NOTE_RENAME))
        static let revoked = FileEvents(rawValue: UInt32(NOTE_REVOKE))
        
        public typealias RawValue = u_int
        
        public var rawValue: UInt32
        
        public init(rawValue: u_int) {
            self.rawValue = rawValue
        }
    }
}

extension SXKernel {
    public func monitor(file: String, events: FileEvents, callback: @escaping (String, FileEvents) -> Bool) {
        let fd = open(file, O_RDONLY)
        var k = event(ident: UInt(fd),
                      filter: Int16(EVFILT_VNODE),
                      flags: UInt16(EV_ADD | EV_ENABLE | EV_CLEAR),
                      fflags: events.rawValue,
                      data: 0,
                      udata: nil)
        self.queues[fd] = FileEventHandler(path: file, ident: fd, callback: callback)
        kevent(fd, &k, 1, nil, 0, nil)
    }
}

internal struct FileEventHandler: KqueueManagable {
    internal var manager: SXKernel?
    internal var path: String
    internal var ident: Int32
    internal var callback: (String, SXKernel.FileEvents) -> Bool
    
    internal func runloop(_ ev: event) {
        if !callback(path, SXKernel.FileEvents(rawValue: ev.fflags)){
            self.manager?.remove(ident: ident, for: .vnode)
        }
    }
    
    public init(path: String, ident: Int32, callback: @escaping (String, SXKernel.FileEvents) -> Bool) {
        self.ident = ident
        self.path = path
        self.callback = callback
    }
}

