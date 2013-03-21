require 'netbat/proto_proc'
require 'netbat/msg'

require 'timeout'
require 'ipaddr'
require 'set'

module Netbat

#initial attempt at raw tcp socket NAT
#hole punching
class NN1 < PunchProcDesc
	
	def self.supports?(my_type, peer_type)
		s = Set.new [Msg::HostType::FILTER, Msg::HostType::NAT]
		
		if s.include?(my_type) && s.include?(peer_type)
			return true
		end

		return false
	end

	register(self)

	OPCODE = Msg::OpCode::NN1

	def self.next_port
		offset = 1024
		return rand(2**16 - offset) + offset
	end

	def self.client(ctx, local_info)
		pproc = ProtoProc.new(ctx)

		pdesc = self
		pproc.init do
			@src_port = pdesc.next_port()
			send_msg(Msg.new(
				:op_code =>	OPCODE,
				:addr => Addr.new(
					:ip => local_info.ipv4.to_i,
					:port => @src_port
				)
			))

			trans_null()
		end

		pproc.on_recv :init do |msg|
			if msg.check(:op_code => OPCODE)
				if msg.addr.ip == 0 || !(1025..(2**16-1)).include?(msg.addr.port)
					proto_error("invalid ip or port: #{msg.inspect}")
				else
					addr = IPAddr::ipv4_from_int(msg.addr.ip).to_s
					@log.debug "connect to #{addr}:#{msg.addr.port}"

					u = UDPSocket.new
					u.bind("0.0.0.0", @src_port)
					u.send("client", 0, addr, msg.addr.port)

					failure("asdfasdf")
				end
			else
				proto_error("unexpected response: #{msg.inspect}")
			end
		end

		return pproc
	end


	def self.server(ctx, local_info)
		pproc = ProtoProc.new(ctx)
		
		pdesc = self
		pproc.on_recv :init do |msg|
			@log.debug "BF0 msg: #{msg.inspect}"
			if msg.error?
				proto_error("error: (#{msg.err_type.inspect}) #{msg.err.inspect}")
			elsif msg.check(:op_code => OPCODE)
				src_port = pdesc.next_port()
				addr = IPAddr::ipv4_from_int(msg.addr.ip).to_s

				@log.debug "udp to #{addr}:#{msg.addr.port}"
				u = UDPSocket.new
				u.bind("0.0.0.0", src_port)
				u.send("server", 0, addr, msg.addr.port)
	
				send_msg(Msg.new(
					:op_code => OPCODE,
					:addr => Addr.new(
						:ip => local_info.ipv4.to_i,
						:port => src_port,
					),
				))

				failure("blah")
			else
				proto_error("ignoring unexpected message: #{msg.inspect}")
			end
		end
				
		return pproc
	end

end

end