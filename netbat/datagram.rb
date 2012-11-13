require 'netbat/datagram/socket'

module Netbat::Datagram
	
class Demuxer
	attr_reader :socket	

	def initialize(dg_socket, &ctx_factory)
		if !dg_socket.is_a?(Datagram::Socket)
			raise ArgumentError.new, "dg_socket must be a Socket. got: #{dg_socket.inspect}"
		end
		@socket = dg_socket

		if ctx_factory.nil?
			raise ArgumentError.new, "ctx_factory function must be provided"			
		end
		@ctx_factory = ctx_factory

		@active = {}
		@active_mtx = Mutex.new
	end

	def demux(&bloc)
		if bloc.nil?
			raise ArgumentError.new, "function must be provided"			
		end
		
		@socket.on_recv do |msg, from_addr|
			@active_mtx.synchronize do
				if !@active.has_key?(from_addr)
					@active[from_addr] = @ctx_factory.call(from_addr, msg)
				else
					bloc.call(@active[from_addr], msg)
				end
			end
		end
		
		@socket.on_close do 
			return #this returns out of this function, not just the block
		end

		Thread.stop
		raise "shouldnt ever get here"
	end
end
	
end


