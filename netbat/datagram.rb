require 'netbat/datagram/socket'
require 'netbat/msg'

module Netbat::Datagram

#OOB datagram connection container
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

#helper functions for a OOB datagram connection
#takes care of encoding/decoding messages
class ConnectionCtx < Connection

	def initialize(dg_socket, peer_addr, local_info)
		super(dg_socket, peer_addr)

		@local_info = local_info
		@current_proc = nil
		@current_proc_mtx = Mutex.new
		@log = Netbat::LOG
	end

	def log_str(s)
		return "#{self.class}: #{s}"	
	end

	def send_msg(msg)
		#"msg: #{msg.inspect}\n#{msg.methods.sort.inspect}"
		super(Base64::encode64(msg.to_s))
	end

	def decode_message(msg)
		return Netbat::Msg::parse(Base64::decode64(msg))
	end

	def recv(msg)
		dm = decode_message(msg)
		proc_recv(dm)
	end

	def current_proc_lock(&bloc)
		@current_proc_mtx.synchronize do 
			bloc.call()
		end
	end

	#dispatch received messages to the current procedure
	def proc_recv(decoded_msg)
		current_proc_lock do 
			if @current_proc.nil?
				@log.debug log_str("dropped msg: #{decoded_msg.inspect}")
			else
				@current_proc.recv(decoded_msg)
			end
		end
	end

	#decode an error message into a protobuf
	#reset message
	def decode_err(err)
		return Netbat::Msg.new(
			:op_code => Netbat::Msg::OpCode::RESET,
			:err => err.msg,
			:err_type => err.err_type
		)
	end

	def recv_err(err)
		e = decode_err(err)
		proc_recv_err(e)
	end
	
	#dispatch error messages to the current procedure
	def proc_recv_err(err)
		current_proc_lock do
			if @current_proc.nil?
				@log.debug log_str("dropped err: #{err.inspect}")
			else
				#@log.debug log_str("recv err: #{err.inspect}")
				@current_proc.recv(err)
			end
		end
	end

end

#filter out messages not from the given peer_addr
class Filter

	def initialize(dg_socket, peer_addr)
		if !dg_socket.is_a?(Socket)
			raise ArgumentError.new, "dg_socket must be a Socket. got: #{dg_socket.inspect}"
		end

		@socket = dg_socket
		@peer = peer_addr
		@log = Netbat::LOG
	end

	def on_msg(&bloc)
		@socket.on_recv do |msg, from_addr|
			if from_addr == @peer
				bloc.call(msg)
			else
				@log.debug "filtered out message from: #{from_addr.inspect}"
			end
		end
	end

	def on_err(&bloc)
		@socket.on_err do |err, from_addr|
			if from_addr.node == @peer.node && from_addr.domain == @peer.domain
				bloc.call(err)
			else
				@log.debug "filtered out error from: #{from_addr.inspect}"
			end
		end
	end
	
end

#demultiplex messages from multiple peers into
#different connection context objects
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
		@clock = nil
	end

	#set clock call back
	def on_clock(&bloc)
		@clock = bloc
	end

	#demultiplex to callback function
	def demux(&bloc)
		if bloc.nil?
			raise ArgumentError.new, "function must be provided"			
		end
		
		@socket.on_recv do |msg, from_addr|
			@log.debug Netbat::thread_list()
			@active_mtx.synchronize do
				@log.debug("active: #{@active.keys.inspect}")
				if !@active.has_key?(from_addr)
					#if this is a new connection, generate a context for it
					new_ctx = @ctx_factory.call(from_addr, msg, @active)
					#nil new_ctx means we should ignore this peer for now
					@active[from_addr] = new_ctx if !new_ctx.nil?
				else
					#dispatch the context and message to handler
					bloc.call(@active[from_addr], msg, @active)
				end
				@active[from_addr].inc_peer_seq()
			end
		end

		@socket.on_err do |err, from_addr|
			@log.debug Netbat::thread_list()
			@active_mtx.synchronize do
				@log.debug("active: #{@active.keys.inspect}")
				prefix = "#{from_addr.node}@#{from_addr.domain}"
				reg_prefix = /^#{Regexp::escape(prefix)}/

				#dispatch error messages to all the contexts which
				#match the username. i.e. asdf@example.com/r1 and 
				#asdf@example.com/r2 will both be notified
				@active.each do |addr, ctx|
					next if addr.to_s.match(reg_prefix).nil?
					bloc.call(ctx, err)
				end
			end
		end
		
		@log.debug "demux: wait for activity"
		#callbacks are delegated, so now we just
		#wait and periodically call the clock 
		#function
		i = 0
		loop do 
			break if !@socket.bound?
			sleep(0.1) if i > 0

			@active.each do |from, ctx|
				@clock.call(ctx, @active) 
			end if !@clock.nil?
			i += 1
		end
		@log.debug "demux: finished. returning"
	end
end
	
end


