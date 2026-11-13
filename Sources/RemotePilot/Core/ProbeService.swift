import Foundation
import Darwin

/// 可达性探测：对目标端口发起 TCP 连接（探测失败 ≠ 不能连，可能只屏蔽了端口探测）
enum ProbeService {
    struct Outcome {
        var reachable: Bool
        var latencyMs: Int
        var detail: String?
    }

    static func probe(host: String, port: Int, timeout: TimeInterval = 3) -> Outcome {
        let start = Date()
        guard !host.isEmpty, port > 0, port <= 65535 else {
            return Outcome(reachable: false, latencyMs: 0, detail: L("主机或端口无效"))
        }

        var hints = addrinfo(ai_flags: AI_ADDRCONFIG, ai_family: AF_UNSPEC, ai_socktype: SOCK_STREAM, ai_protocol: IPPROTO_TCP, ai_addrlen: 0, ai_canonname: nil, ai_addr: nil, ai_next: nil)
        var info: UnsafeMutablePointer<addrinfo>?
        let resolved = getaddrinfo(host, String(port), &hints, &info)
        guard resolved == 0, let list = info else {
            return Outcome(reachable: false, latencyMs: 0, detail: L("无法解析主机名"))
        }
        defer { freeaddrinfo(list) }

        var lastDetail: String?
        var cursor: UnsafeMutablePointer<addrinfo>? = list
        while let current = cursor {
            let fd = socket(current.pointee.ai_family, current.pointee.ai_socktype, current.pointee.ai_protocol)
            if fd >= 0 {
                let flags = fcntl(fd, F_GETFL, 0)
                _ = fcntl(fd, F_SETFL, flags | O_NONBLOCK)
                var noSigPipe: Int32 = 1
                setsockopt(fd, SOL_SOCKET, SO_NOSIGPIPE, &noSigPipe, socklen_t(MemoryLayout<Int32>.size))

                let result = connect(fd, current.pointee.ai_addr, current.pointee.ai_addrlen)
                if result == 0 {
                    close(fd)
                    return Outcome(reachable: true, latencyMs: elapsedMs(from: start), detail: nil)
                }
                if errno == EINPROGRESS {
                    var descriptor = pollfd(fd: fd, events: Int16(POLLOUT), revents: 0)
                    let ready = poll(&descriptor, 1, Int32(timeout * 1000))
                    if ready > 0 {
                        var socketError: Int32 = 0
                        var length = socklen_t(MemoryLayout<Int32>.size)
                        getsockopt(fd, SOL_SOCKET, SO_ERROR, &socketError, &length)
                        if socketError == 0 {
                            close(fd)
                            return Outcome(reachable: true, latencyMs: elapsedMs(from: start), detail: nil)
                        }
                        lastDetail = String(cString: strerror(socketError))
                    } else {
                        lastDetail = L("连接超时")
                    }
                } else {
                    lastDetail = String(cString: strerror(errno))
                }
                close(fd)
            }
            cursor = current.pointee.ai_next
        }
        return Outcome(reachable: false, latencyMs: elapsedMs(from: start), detail: lastDetail ?? L("连接失败"))
    }

    private static func elapsedMs(from start: Date) -> Int {
        max(0, Int(Date().timeIntervalSince(start) * 1000))
    }

    /// 批量探测：限制并发，避免把本机连接表打满
    static func probeAll(_ targets: [(id: UUID, host: String, port: Int)], concurrency: Int = 12, timeout: TimeInterval = 3) async -> [UUID: ProbeResult] {
        var results: [UUID: ProbeResult] = [:]
        await withTaskGroup(of: (UUID, ProbeResult).self) { group in
            var pending = targets[...]
            func addTask(_ target: (id: UUID, host: String, port: Int)) {
                group.addTask {
                    let outcome = probe(host: target.host, port: target.port, timeout: timeout)
                    let result = ProbeResult(
                        status: outcome.reachable ? .reachable : .unreachable,
                        latencyMs: outcome.latencyMs,
                        checkedAt: Date(),
                        detail: outcome.detail
                    )
                    return (target.id, result)
                }
            }
            for _ in 0..<min(concurrency, pending.count) {
                if let next = pending.first { addTask(next); pending = pending.dropFirst() }
            }
            while let (id, result) = await group.next() {
                results[id] = result
                if let next = pending.first { addTask(next); pending = pending.dropFirst() }
            }
        }
        return results
    }
}
