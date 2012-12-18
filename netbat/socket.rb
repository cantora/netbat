require 'netbat/log'

module Netbat

#a container with a UDP socket and a peer address
#that has IO like read/write methods
class UDPio < Struct.new(:sock, :addr, :port)
	DEFAULT_READ_SIZE = 1500

	def initialize(*args)
		super(*args)
	
		@udp_w_mtx = Mutex.new
		@udp_r_mtx = Mutex.new
		@log = Netbat::LOG
	end

	def write(data)
		@udp_w_mtx.synchronize do 
			self.sock.send(data, 0, self.addr, self.port)
		end
	end

	def read(amt=DEFAULT_READ_SIZE)
		@udp_r_mtx.synchronize do 
			msg, addr_info = self.sock.recvfrom(amt)
			msg
		end
	end
end

class UDPctx < UDPio

	#udp container that filters out messages that arent
	#from the peer address
	def read(amt=DEFAULT_READ_SIZE)
		@udp_r_mtx.synchronize do 
			loop do 
				msg, addr_info = self.sock.recvfrom(amt)
				if addr_info[1] == self.port \
						&& addr_info[3] == self.addr
					return msg
				end
				@log.debug <<-EOS
dropped msg from #{addr_info[3]}:#{addr_info[1]} \
because it did not come from #{self.addr}:#{self.port}
				EOS
			end
		end
	end
end


end #Netbat