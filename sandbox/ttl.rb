require 'socket'

#error = setsockopt(send_socket, IPPROTO_IP, IP_TTL, &ttl, sizeof(ttl));

s = Socket.new(Socket::AF_INET, Socket::SOCK_STREAM)
saddr = Socket::pack_sockaddr_in(53, "8.8.8.8")
s.setsockopt(Socket::IPPROTO_IP, Socket::IP_TTL, 14)
s.connect(saddr)
s.send("asdf", 0) #, saddr)


