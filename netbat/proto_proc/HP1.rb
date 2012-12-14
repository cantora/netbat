require 'netbat/proto_proc'
require 'netbat/msg'


require 'timeout'
require 'ipaddr'
require 'set'
require 'racket'

module Netbat

class HP1 < PunchProcDesc

	def self.usage()
		str =<<-EOS
HP1: hole punch with udp
	server sends UDP packet out to port 53 through NAT (probably dies on client's NAT)
	client "replies" using OOB data to known dest port using src port 53 and
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

	OPCODE = Msg::OpCode::HP1

	def self.next_port
		offset = 1024
		return rand(2**16 - offset) + offset
	end

	def self.client(ctx, local_info)
		pproc = ProtoProc.new(ctx)

		pdesc = self
		pproc.init do
			@src_port = 53 #dns may not be filtered by NAT/firewall rules
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
			#cleanup :confirm_thread thread if its still running
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
					addr = IPAddr::ipv4_from_int(msg.addr.ip).to_s
					@log.debug "brute force to #{addr}"

					if msg.token.size > 0
						@token = msg.token
						@udpsock = UDPSocket.new
						@udpsock.bind("0.0.0.0", @src_port)

						@confirm_thread = Thread.new do
							Thread.current.abort_on_exception = true
	
							PunchProcDesc::brute_udp(@udpsock, addr, msg.token)
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
				addr = IPAddr::ipv4_from_int(msg.addr.ip).to_s
				@pudp = PunchedUDP.new(@udpsock, addr, msg.addr.port)

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
				addr = IPAddr::ipv4_from_int(msg.addr.ip).to_s

				@log.debug "udp to #{addr}:#{msg.addr.port}"
				u = UDPSocket.new
				u.bind("0.0.0.0", src_port)
				dnspack = Racket::L5::DNS.new
				dnspack.tx_id = 1234
				#dnspack.add_question("google.com", 1, 1)
				#(udp.dstport == 53 or udp.srcport == 53) and (ip.dst == 172.23.193.67 or ip.src == 172.23.193.67)
				u.send(dnspack.to_s, 0, addr, msg.addr.port)
				
				token = PunchProcDesc::new_token()

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
					pudp, outside_port = PunchProcDesc::wait_brute_udp(u, token)
					
					#so our hole punch worked. but still we need to 
					#signal to peer to confirm that it worked
					state_lock do 
						if !pudp.is_a?(PunchedUDP)
							raise "wtf, invalid pudp: #{pudp.inspect}"
						end

						send_msg(Msg.new(
							:op_code => OPCODE,
							:addr => Addr.new(
								:ip => local_info.ipv4.to_i,
								:port => outside_port.to_i,
							)
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