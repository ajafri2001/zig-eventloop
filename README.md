An asynchronous server built completely from scratch using low-level raw posix system API's.

pre-requisites - Zig 0.13 installed and on a posix system

build instructions - clone and run
```zig
zig build -Doptimize=ReleaseSafe
```

Benchmarked by running `wrk --latency -t12 -c400 -d30s http://localhost:8080`

![image](https://github.com/user-attachments/assets/0a7162e5-4810-42c0-8534-240c5f01bbaf)
