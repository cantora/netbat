require 'socket'

s = Socket.new(Socket::AF_INET, Socket::SOCK_RAW, Socket::IPPROTO_RAW)

puts s.methods.sort.inspect
puts s.class.ancestors.inspect
data = s.sendmsg("raw world", Socket::sockaddr_in(0, "127.0.0.1") )



