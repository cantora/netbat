require 'socket'


s = Socket.new(Socket::AF_INET, Socket::SOCK_RAW, Socket::IPPROTO_TCP)
sockaddr = Socket.pack_sockaddr_in(48484, '0.0.0.0')
s.bind( sockaddr )

loop do 
	puts "wait for data..."
	data = s.recvfrom(512)

	puts "got data:"
	puts data.inspect
end
