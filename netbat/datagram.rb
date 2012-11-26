require 'netbat/datagram/socket'

module Netbat::Datagram

class Connection
	attr_reader :peer_addr, :seq, :peer_seq, :socket

	def initialize(dg_socket, peer_addr)
		@peer_addr = peer_addr
		@peer_seq = 0
		@seq = 0
		@socket = dg_socket
	end

	def inc_seq
		@seq += 1
	end

	def inc_peer_seq
		@peer_seq += 1
	end

	def send_msg(msg)
		@socket.send_msg(peer_addr, msg)
		inc_seq()
	end
end

class Filter

	def initialize(dg_socket, peer_addr)
		if !dg_socket.is_a?(Socket)
			raise ArgumentError.new, "dg_socket must be a Socket. got: #{dg_socket.inspect}"
		end

		@socket = dg_socket
		@peer = peer_addr
	end

	def on_msg(&bloc)
		@socket.on_recv do |msg, from_addr|
			if from_addr == @peer
				bloc.call(msg)
			end
		end
	end

	def on_err(&bloc)
		@socket.on_err do |err, from_addr|
			if from_addr == @peer
				bloc.call(err)
			end
		end
	end
	
end


class Demuxer

	attr_reader :socket	

	def initialize(dg_socket, &ctx_factory)
		if !dg_socket.is_a?(Socket)
			raise ArgumentError.new, "dg_socket must be a Socket. got: #{dg_socket.inspect}"
		end
		@socket = dg_socket

		if ctx_factory.nil?
			raise ArgumentError.new, "ctx_factory function must be provided"			
		end
		@ctx_factory = ctx_factory

		@active = {}
		@active_mtx = Mutex.new
		@log = Netbat::LOG
	end

	def demux(&bloc)
		if bloc.nil?
			raise ArgumentError.new, "function must be provided"			
		end
		
		@socket.on_recv do |msg, from_addr|
			@log.debug Netbat::thread_list()
			@active_mtx.synchronize do
				@log.debug("active: #{@active.keys.inspect}")
				if !@active.has_key?(from_addr)
					@active[from_addr] = @ctx_factory.call(from_addr, msg)
				else
					bloc.call(@active[from_addr], msg)
				end
				@active[from_addr].inc_peer_seq()
			end
		end
		
		@log.debug "demux: wait for activity"
		loop do 
			break if !@socket.bound?
		end
		@log.debug "demux: finished. returning"
	end
end
	
end


