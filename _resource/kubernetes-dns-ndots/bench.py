# Average time for 300 lookups of one name, through the Pod's normal resolver.
#   kubectl cp bench.py app-default:/tmp/bench.py
#   kubectl exec app-default -- python /tmp/bench.py api.github.com
import socket, sys, time
name, n = sys.argv[1], 300
start = time.perf_counter()
for _ in range(n):
    socket.getaddrinfo(name, 443, proto=socket.IPPROTO_TCP)
print(f"{name:18s} {n} lookups: {(time.perf_counter() - start) * 1000 / n:.2f} ms avg")
