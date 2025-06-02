const std = @import("std");
const print = std.debug.print;
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

    print("server on port 8080\n", .{});

    try posix.setsockopt(listener, posix.SOL.SOCKET, posix.SO.REUSEADDR, &std.mem.toBytes(@as(c_int, 1)));
    try posix.bind(listener, &addr.any, addr.getOsSockLen());
    try posix.listen(listener, 512);

    const fd = try posix.epoll_create1(0x80000);

    defer std.posix.close(listener);
    defer posix.close(fd);

    var event_1 = linux.epoll_event{ .events = linux.EPOLL.IN, .data = .{ .fd = listener } };
    try posix.epoll_ctl(fd, linux.EPOLL.CTL_ADD, listener, &event_1);

    var ready_list: [256]linux.epoll_event = undefined;

    print("listening...\n", .{});

    while (true) {
        const ready_count = posix.epoll_wait(fd, &ready_list, -1);
        for (ready_list[0..ready_count]) |ready| {
            const ready_socket = ready.data.fd;
            if (ready_socket == listener) {
                const client_socket = try posix.accept(listener, null, null, posix.SOCK.NONBLOCK);
                errdefer posix.close(client_socket);
                var event = linux.epoll_event{ .events = linux.EPOLL.IN, .data = .{ .fd = client_socket } };
                try posix.epoll_ctl(fd, linux.EPOLL.CTL_ADD, client_socket, &event);
            } else {
                var buf: [1024]u8 = undefined; // stack > heap
                const request_size: usize = posix.read(ready_socket, buf[0..]) catch 0;
                print("{s}", .{buf[0..request_size]});
                if (request_size == 0 or (ready.events & linux.EPOLL.RDHUP) != 0) {
                    // parseHttpReq(buf[0..request_size]);
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

const HttpRequest = struct {
    method: []const u8,
    path: []const u8,
    version: []const u8,
    // umm the header_key will have ":" at the end :sweat
    headers: []const struct { header_key: []const u8, header_value: []const u8 },
    body: []const u8,
};

pub fn parseHttpReq(to_parse: []u8) !HttpRequest {
    const lines = std.mem.splitSequence(u8, to_parse, "\r\n");

    const method = std.mem.splitScalar([]u8, lines[0], " ").first;
    const path = method.next();
    const version = method.next();
}
