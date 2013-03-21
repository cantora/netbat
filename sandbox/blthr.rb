require 'socket'
require 'blather/client'

setup("ulyuly@jabber.org", "pass")

subscription :request? do |s|
  puts "subscription req: #{s.inspect}"
  write_to_stream s.approve!
end

message :chat?, :body do |m|
  puts "chat: #{m.inspect}"
end

when_ready {
	puts "ready!"

	Thread.new do 
		Thread.current.abort_on_exception = true
		u = UDPSocket.new
		u.bind("127.0.0.1", 6868)
	
		i = 0
		loop do 
			say("ujijigo@jabber.iitsp.com", u.recvfrom(256)[0])
			i += 1
			puts "sent message #{i}"
		end
	end
}


client.run
