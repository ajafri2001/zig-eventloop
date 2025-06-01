const std = @import("std");
const posix = std.posix;
const linux = std.os.linux;

const response =
    "HTTP/1.1 200 OK\r\n" ++
    "Content-Type: text/plain\r\n" ++
    "Content-Length: 13\r\n" ++
    "Connection: close\r\n" ++
    "\r\n" ++
    "Hello, World!";

pub fn main() !void {
    const addr = std.net.Address.initIp4([4]u8{ 127, 0, 0, 1 }, 8080);
    const listener = try std.posix.socket(std.posix.AF.INET, 0x801, std.posix.IPPROTO.TCP);

    std.debug.print("server on port 8080\n", .{});

    try posix.setsockopt(listener, posix.SOL.SOCKET, posix.SO.REUSEADDR, &std.mem.toBytes(@as(c_int, 1)));
    try posix.bind(listener, &addr.any, addr.getOsSockLen());
    try posix.listen(listener, 512);

    const fd = try posix.epoll_create1(0x80000);

    defer std.posix.close(listener);
    defer posix.close(fd);

    var event_1 = linux.epoll_event{ .events = linux.EPOLL.IN, .data = .{ .fd = listener } };
    try posix.epoll_ctl(fd, linux.EPOLL.CTL_ADD, listener, &event_1);

    var ready_list: [256]linux.epoll_event = undefined;

    std.debug.print("listening...\n", .{});

    while (true) {
        const ready_count = posix.epoll_wait(fd, &ready_list, -1);
        for (ready_list[0..ready_count]) |ready| {
            const ready_socket = ready.data.fd;
            if (ready_socket == listener) {
                const client_socket = try posix.accept(listener, null, null, posix.SOCK.NONBLOCK);
                posix.close(client_socket);
                var event = linux.epoll_event{ .events = linux.EPOLL.IN, .data = .{ .fd = client_socket } };
                try posix.epoll_ctl(fd, linux.EPOLL.CTL_ADD, client_socket, &event);
            } else {
                var buf: [1024]u8 = undefined;
                const read = posix.read(ready_socket, &buf) catch 0;
                if (read == 0 or (ready.events & linux.EPOLL.RDHUP) != 0) {
                    try posix.epoll_ctl(fd, linux.EPOLL.CTL_DEL, ready_socket, null);
                    posix.close(ready_socket);
                } else {
                    _ = try posix.write(ready_socket, response);
                    try posix.epoll_ctl(fd, linux.EPOLL.CTL_DEL, ready_socket, null);
                    posix.close(ready_socket);
                }
            }
        }
    }
}
