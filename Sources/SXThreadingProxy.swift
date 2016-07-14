//
//  SXThreadingProxy.swift
//  spartanX
//
//  Created by yuuji on 7/8/16.
//
//

import Foundation

public protocol SXThreadingProxy {
    mutating func execute(block: () -> Void)
}

#if os(OSX) || os(iOS) || os(watchOS) || os(tvOS)

public struct GrandCentralDispatchQueue : SXThreadingProxy {
    public var queue: DispatchQueue
    
    public init(_ queue: DispatchQueue) {
        self.queue = queue
    }
    
    public func execute(block: () -> Void) {
        queue.async(execute: block)
    }
}
    
#endif

public class SXThreadPool : SXThreadingProxy {
    public var numberOfThreads: Int
    var threads: [SXThread]
    
    public static let `default` = SXThreadPool(nthreads: 4)
    
    public func execute(block: ()->Void) {
        threads.sorted{ $0.queue.count < $1.queue.count }.first!.execute(block: block)
    }
    
    public init(nthreads: Int) {
        numberOfThreads = nthreads
        threads = [SXThread](count: nthreads) { _ in SXThread() }
    }
}

public class SXThread {
    
    class BlockQueue {
        
        var count: Int = 0
        var mutex: pthread_mutex_t = pthread_mutex_t()
        var blocks = [() -> Void]()
        
        var mutexPointer: UnsafeMutablePointer<pthread_mutex_t> {
            return getMutablePointer(&mutex)
        }
        
        init() {
            pthread_mutex_init(&mutex, nil)
        }
    }
    
    #if os(OSX) || os(iOS) || os(watchOS) || os(tvOS)
    var thread: pthread_t?
    #elseif os(Linux) || os(FreeBSD)
    var thread: pthread_t = pthread_t()
    #endif
    var queue = BlockQueue()
    
    public func execute(block: () -> Void) {
        pthread_mutex_lock(queue.mutexPointer)
        queue.blocks.append(block)
        queue.count += 1
        pthread_mutex_unlock(queue.mutexPointer)
    }
    
    init() {
        pthread_create(&thread, nil, { (pointer) -> UnsafeMutablePointer<Void>? in
            
            #if os(OSX) || os(iOS) || os(watchOS) || os(tvOS)
            let blockQueue = UnsafeMutablePointer<BlockQueue>(pointer).pointee
            #else
            let blockQueue = UnsafeMutablePointer<BlockQueue>(pointer!).pointee
            #endif
            
            while true {
                while blockQueue.count > 0 {
                    blockQueue.blocks.first!()
                    pthread_mutex_lock(blockQueue.mutexPointer)
                    _ = blockQueue.blocks.removeFirst()
                    blockQueue.count -= 1
                    pthread_mutex_unlock(blockQueue.mutexPointer)
                }
            }
            }, UnsafeMutablePointer<Void>(getMutablePointer(&self.queue)))
    }
}
