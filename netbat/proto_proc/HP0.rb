require 'netbat/proto_proc'
require 'netbat/msg'

require 'timeout'
require 'ipaddr'
require 'set'

module Netbat

class HP0 < PunchProcDesc

	def self.usage()
		str =<<-EOS
HP0: hole punch with udp
	server sends UDP packet out through NAT (probably dies on client's NAT)
	client "replies" using OOB data to known dest port and src port and
	should get through server's NAT.
	this will probably fail if the NAT port translates aggressively, but
	still might work if the port translation doesnt always translate the port
	(i.e. only translates source port if someone else is using it). 


		EOS

		return str
	end
	
	def self.supports?(my_type, peer_type)
		return true
	end

	register(__FILE__, self)

	OPCODE = Msg::OpCode::HP0

	def self.next_port
		offset = 1024
		return rand(2**16 - offset) + offset
	end

	def self.client(ctx, local_info)
		pproc = ProtoProc.new(ctx)

		pdesc = self
		pproc.init do
			@src_port = pdesc.next_port()
			#send peer my IP address and an arbitrary source port
			#i plan on using
			send_msg(Msg.new(
				:op_code =>	OPCODE,
				:addr => Addr.new(
					:ip => local_info.ipv4.to_i,
					:port => @src_port
				)
			))

			trans_null()
		end

		pproc.on_terminate do 
			#cleanup @confirm_thread thread if its still running
			if !@confirm_thread.nil?
				@confirm_thread.kill
				@confirm_thread = nil
			end
		end

		pproc.on_recv :init do |msg|
			if msg.check(:op_code => OPCODE)
				if msg.addr.ip == 0 || !(1025..(2**16-1)).include?(msg.addr.port)
					proto_error("invalid ip or port: #{msg.inspect}")
				else
					#peer sent us their IP address and the source port
					#they used to punch a hole in their NAT. 
					addr = IPAddr::ipv4_from_int(msg.addr.ip).to_s
					@log.debug "connect to #{addr}:#{msg.addr.port}"

					u = UDPSocket.new
					u.bind("0.0.0.0", @src_port)
					#this should go through the server's NAT, as they
					#already sent us a packet
					u.send("client", 0, addr, msg.addr.port)
					@pudp = PunchedUDP.new(u, addr, msg.addr.port)
					
					if msg.token.size > 0
						#the server gave us a token to use for confirmation
						#so we should send that message until we get an
						#acknowledgement (in OOB channel) from the server
						@token = msg.token
						@confirm_thread = Thread.new do
							Thread.current.abort_on_exception = true
	
							PunchProcDesc::confirm_udp(@pudp, msg.token)
						end

						trans(:wait_for_confirm)
					else
						proto_error("expected a non-empty token")
					end
				end
			else
				proto_error("unexpected response: #{msg.inspect}")
			end
		end #recv :init

		pproc.on_recv :wait_for_confirm do |msg|
			if msg.check(:op_code => OPCODE)
				@confirm_thread.kill
				@confirm_thread = nil

				#optimization: peer doesnt have to wait for 2 seconds
				#to be certain no more confirm tokens are being sent
				#if it sees different data than the token
				@pudp.snd(
					loop { x = PunchProcDesc::new_token(); break x if x != @token }
				)
				success(@pudp)
			else
				proto_error("unexpected response: #{msg.inspect}")
			end
		end #recv :wait_for_confirm

		return pproc
	end

	def self.server(ctx, local_info)
		pproc = ProtoProc.new(ctx)
		
		pproc.on_terminate do 
			#cleanup :wait_udp thread if its still running
			if !@wait.nil?
				@wait.kill
				@wait = nil
			end
		end

		pdesc = self
		pproc.on_recv :init do |msg|
			@log.debug "msg: #{msg.inspect}"
			if msg.error?
				proto_error("error: (#{msg.err_type.inspect}) #{msg.err.inspect}")
			elsif msg.check(:op_code => OPCODE)
				src_port = pdesc.next_port()
				#client sent us their IP and source port
				addr = IPAddr::ipv4_from_int(msg.addr.ip).to_s

				#send a packet out to client which will probably 
				#get dropped by their NAT. this should cause our
				#NAT to open a translation to accept response 
				#UDP packets from the client
				@log.debug "udp to #{addr}:#{msg.addr.port}"
				u = UDPSocket.new
				u.bind("0.0.0.0", src_port)
				u.send("server", 0, addr, msg.addr.port)
				
				token = PunchProcDesc::new_token()

				#tell client our source port and IP address.
				#also give them a token to send via UDP so
				#we can confirm connectivity
				send_msg(Msg.new(
					:op_code => OPCODE,
					:addr => Addr.new(
						:ip => local_info.ipv4.to_i,
						:port => src_port,
					),
					:token => token
				))

				#this will get killed by the idle timer unless it
				#succeeds in a timeley manner
				@wait = Thread.new do 
					Thread.current.abort_on_exception = true

					#wont return unless successful
					pudp = PunchProcDesc::wait_udp(u, token)
					#so our hole punch worked. but still we need to 
					#signal to peer to confirm that it worked
					state_lock do 
						if !pudp.is_a?(PunchedUDP)
							raise "wtf, invalid pudp: #{pudp.inspect}"
						end

						#tell client that we received a UDP message
						#with the confirmation token
						send_msg(Msg.new(
							:op_code => OPCODE
						))

						#clear all the token messages out of
						#the IO if they are there
						PunchProcDesc::clean_pudp(pudp, token)	
						make_transition(success(pudp))
					end
				end #Thread

				trans(:wait_udp)
			else
				proto_error("ignoring unexpected message: #{msg.inspect}")
			end
		end
		
		return pproc
	end

end

end