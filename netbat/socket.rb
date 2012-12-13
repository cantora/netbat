require 'netbat/log'

module Netbat

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
			msg, addr_info = recvfrom(amt)
			msg
		end
	end

	def recvfrom(amt)
		return self.sock.recvfrom(amt)
	end
end

class UDPctx < UDPio

	def read(amt=DEFAULT_READ_SIZE)
		@udp_r_mtx.synchronize do 
			loop do 
				msg, addr_info = recvfrom(amt)
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