# spartanX

spartanX is a protocol oriented socket library written in swift that so-far support ipv4, ipv6 and unix stream sockets. SpartanX is using a hybrid of event looping and multi-threading model that maximize the scale of connections without fall into callback hell and race condition. Sockets in spartanX can be use as stand-alone component as well manage by SXKernel.

spartanX currently support some features that no one has done in swift web framework.

* A very special threading model of hybriding multi-threading and event-driven io with blocking socket that does not block any thread(see Threading Model).
* sendfile() support with optional header (does not copy data to user-space from kernel)
* Awesome SXSocketAddress that does things right.
* ipv4, ipv6, unix domain socket
* Making any arbinary object in swift to send tho socket by confirming to transmittable protocol
* Oneshot connection socket 
* Standalone DNS api 

spartanX is build for server-side use with client-side component.

# Threading Model

SpartanX model each server-thread as a "Kernel", each kernel is running its own kqueue[FreeBSD/OSX]/epoll[Linux]. A central manager is reponse for dispatch a new connection to different available kernels to take advantage of multi-core system. Since once connection is added to the Kernel it will handle by the kernel using event-looping so it guarantees that your connection will Always synchronized.

Once no more events for Kernel to handle, the thread will put into sleep until recevices new connection.

# How data drain from socket internally

Unlike most of the event looping based library, spartanX is using blocking IO intelligently since generally blocking IO suppose to be less expensive than non-blocking IO.

# Services and Queue

In spartanX, a Service is a protocol that blueprints how the socket should behave and how payload from socket should be handled. A service defines a set of abstract of handlers, that provides a shared interface for up to thousands of socket to use. This model make spartanX connections much eaiser to adopt multiple network protocols and switching among them. Each services can also define what sending method is supported. For example, a strict HTTP protocol can easily use both send/sendto/sendfile/sendmsg. But if a connection is running on top of tls, let's say HTTPS, then sendfile is definitly not going to available. Therefore the "supportedMethods" are an option set of methods supported the service can define. 

Each connection from a same socket is abstracted as a queue, which also has "supportedMethods" as well for similar reason. As mensioned before, the "service" of a queue is using can change in runtime however you like. a Queue is also an interface for send() objects.

# Transmittable

An object can confirm to protocol Transmittable to specify how it want to be transmitted. This can let user to do low-level optimization on socket and protocols such as TCP using for example, setsockopt.


