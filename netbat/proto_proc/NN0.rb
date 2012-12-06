require 'netbat/proto_proc'
require 'netbat/msg'

require 'timeout'
require 'ipaddr'
require 'set'
require 'racket'

module Netbat

#initial attempt at raw tcp socket NAT
#hole punching
class NN0 < PunchProcDesc
	
	def self.supports?(my_type, peer_type)
		s = Set.new [Msg::HostType::FILTER, Msg::HostType::NAT]
		
		if s.include?(my_type) && s.include?(peer_type)
			return true
		end

		return false
	end

	register(self)

	OPCODE = Msg::OpCode::NN0

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

					n = Racket::Racket.new
					n.iface = local_info.ifc.to_s
					
					n.l3 = Racket::L3::IPv4.new
					n.l3.src_ip = local_info.ifc_ipv4
					n.l3.dst_ip = addr.to_s
					n.l3.protocol = 0x6
					n.l3.ttl = 255
					n.l4 = Racket::L4::TCP.new
					n.l4.src_port = @src_port
					n.l4.dst_port = msg.addr.port
					n.l4.seq = msg.tcp_ack + 1 #rand(2**32)
					n.l4.ack = msg.tcp_seq + 1
					#n.l4.flag_syn = 1
					n.l4.flag_ack = 1
					n.l4.window = 4445
					
					n.l4.fix!(n.l3.src_ip, n.l3.dst_ip, "")
					amt = n.sendpacket

					@log.debug "sent #{amt} bytes"

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

				@log.debug "syn to #{addr}:#{msg.addr.port}"

				n = Racket::Racket.new
				n.iface = local_info.ifc.to_s
				
				n.l3 = Racket::L3::IPv4.new
				n.l3.src_ip = local_info.ifc_ipv4
				n.l3.dst_ip = addr.to_s
				n.l3.protocol = 0x6
				n.l3.ttl = 255
				n.l4 = Racket::L4::TCP.new
				n.l4.src_port = src_port
				n.l4.dst_port = msg.addr.port
				n.l4.seq = rand(2**32)
				n.l4.ack = rand(2**32)
				n.l4.flag_syn = 1
				n.l4.flag_ack = 1
				n.l4.window = 4445
				
				n.l4.fix!(n.l3.src_ip, n.l3.dst_ip, "")
				amt = n.sendpacket

				@log.debug "sent #{amt} bytes"

				send_msg(Msg.new(
					:op_code => OPCODE,
					:addr => Addr.new(
						:ip => local_info.ipv4.to_i,
						:port => src_port,
					),
					:tcp_seq => n.l4.seq,
					:tcp_ack => n.l4.ack
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