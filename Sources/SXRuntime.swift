
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
//e2fsprogs-libuuid

import Foundation
import CKit

#if os(Linux)
import spartanXLinux // epoll
#endif

public protocol KqueueManagable {
    var ident: Int32 { get }
    var manager: SXKernel? { get set }
    func runloop(_ ev: event)
}

#if os(Linux)
public typealias event = epoll_event
#else
public typealias event = Foundation.kevent
#endif

public struct SXKernelManager {
    public static var `default`: SXKernelManager?
    var kernels = [SXKernel]()
    var map = [Int32 : SXKernel]()
}

public extension SXKernelManager {
    
    public static func initializeDefault() {
        `default` = SXKernelManager(maxCPU: 1, evs_cpu: 5120)
    }
    
    public mutating func manage<Managable: KqueueManagable>(_ managable: Managable, setup: ((inout Managable) -> ())?) {
        var target = managable
        #if os(Linux)
        if let _ = target as? SocketType {
            (target as! SocketType).setBlockingMode(block: false)
        }
        #endif
        setup?(&target)
        self.register(target)
    }

    @inline(__always)
    internal mutating func register(_ queue: KqueueManagable) {
        let _leastBusyKernel = leastBusyKernel()
        map[queue.ident] = _leastBusyKernel
        _leastBusyKernel?.register(queue)
    }
    
    internal mutating func unregister(ident: Int32, of filter: SXKernel.Filter) {
        let kernel = map[ident]
        kernel?.remove(ident: ident, for: filter)
        map[ident] = nil
    }
    
    @inline(__always)
    func leastBusyKernel() -> SXKernel? {
        return kernels.sorted {
            $0.queues.count < $1.queues.count
        }.first
    }
}

public extension SXKernelManager {
    init(maxCPU: Int, evs_cpu: Int) {
        self.kernels = [SXKernel](count: maxCPU) {_ in
            return SXKernel(events_count: evs_cpu)
        }
    }
}

public final class SXKernel {
    
    public var thread: SXThread
    var mutex: pthread_mutex_t
    
    var kq: Int32
    
    var events: [event]

    // user queues
    var queues: [Int32: KqueueManagable]
    
    // events count
    var count = 0
    
    // active events count
    var actived = false
    
    #if os(Linux)
    private typealias ev_raw_t = UInt32
    #else
    private typealias ev_raw_t = Int16
    #endif
    
    enum Filter {
        case read
        case write
        case vnode
        
        fileprivate var value: ev_raw_t {
            #if os(Linux)
            switch self {
            case .read: return EPOLLIN.rawValue
            case .write: return EPOLLOUT.rawValue
            case .vnode: return EPOLLOUT.rawValue | EPOLLIN.rawValue | EPOLLET.rawValue
            }
            #else
            switch self {
            case .read: return Int16(EVFILT_READ)
            case .write: return Int16(EVFILT_WRITE)
            case .vnode: return Int16(EVFILT_VNODE)
            }
            #endif
        }
        
        fileprivate var internalVal: Int32 {
            switch self {
            case .read: return 1
            case .write: return 2
            case .vnode: return 3
            }
        }
    }
    
    init(events_count: Int) {
        thread = SXThread()
        mutex = pthread_mutex_t()
        self.queues = [:]
        #if os(Linux)
        kq = epoll_create1(0)
        #else
        kq = kqueue()
        #endif
        self.events = [event](repeating: event(), count: events_count)
        pthread_mutex_init(&mutex, nil)
    }
    
}

extension SXKernel {
    func withMutex<Result>(_ execute: () -> Result) -> Result {
        pthread_mutex_lock(&mutex)
        let r = execute()
        pthread_mutex_unlock(&mutex)
        return r
    }
}



// Kevent
extension SXKernel {
    
    private func kqueue_end() {
        self.withMutex {
            self.actived = false
        }
    }
    /*
    fileprivate func ident(type: EventType, id: Int32) -> Int32 {
        return type.internalVal + id * 10
    }
    */
    private func kqueue_runloop() {
        
        if (self.withMutex { () -> Bool in
            
            if self.count == 0 {
                return true
            }
            return false
        }) {
            kqueue_end()
            return
        }
        
        
        #if os(Linux)
            let nev = epoll_wait(self.kq, &self.events, Int32(self.events.count), -1)
        #else
            let nev = kevent(self.kq, nil, 0, &self.events, Int32(self.events.count), nil)
        #endif
        
        if nev < 0 {
            self.thread.exec {
                self.kqueue_runloop()
            }
        }
        
        if nev == 0 {
            kqueue_end()
        }
        
        for i in 0..<Int(nev) {
            let event = self.events[i]
            #if os(Linux)
                let queue = self.queues[Int32(event.data.fd)]
            #else
                let queue = self.queues[Int32(event.ident)]
            #endif
            
            queue?.runloop(event)
        }
        
        self.thread.exec {
            self.kqueue_runloop()
        }
    }
    
    func activate() {
        self.withMutex{
            actived = true
        }
        
        self.thread.execute {
            self.kqueue_runloop()
        }
    }
    
    func register(_ queue: KqueueManagable, for kind: Filter = .read) {
        withMutex {
            self.queues[queue.ident] = queue
            self.queues[queue.ident]!.manager = self
            
            #if os(Linux)
                var ev = epoll_event()
                ev.events = kind.value | EPOLLONESHOT.rawValue | EPOLLET.rawValue;
                ev.data.fd = queue.ident
                epoll_ctl(kq, EPOLL_CTL_ADD, queue.ident, &ev)
            #else
                var k = event(ident: UInt(queue.ident),
                              filter: kind.value,
                              flags: UInt16(EV_ADD | EV_ENABLE | EV_ONESHOT),
                              fflags: 0, data: 0,
                              udata: nil)
                kevent(kq, &k, 1, nil, 0, nil)
            #endif
            count += 1
        }
        
        if !actived {
            activate()
        }
    }
    
    func remove(ident: Int32, for filter: Filter) {
        withMutex {
            self.queues[ident] = nil
            #if os(Linux)
            var ev = epoll_event()
            ev.events = filter.value;
            ev.data.fd = ident
            epoll_ctl(kq, EPOLL_CTL_DEL, ident, &ev)
            #else
            var k = event(ident: UInt(ident),
                            filter: filter.value,
                            flags: UInt16(EV_DELETE | EV_DISABLE | EV_RECEIPT),
                            fflags: 0,
                            data: 0,
                            udata: nil)
            kevent(kq, &k, 1, nil, 0, nil)
            #endif
            count -= 1
        }
    }
}
