require 'netbat/proto_proc'
require 'netbat/msg'

require 'timeout'
require 'socket'

module Netbat

#simplest firewall hole punch with no TCP state trickery
#does not require super user privs on either side
class BothFiltered0 < ProtoProcDesc
	
	def self.supports?(my_type, peer_type)
		if my_type == Msg::HostType::Filter \
				&& peer_type == Msg::HostType::Filter
			return true
		end

		return false
	end

	register(self)

	OPCODE = Msg::OpCode::BF0

	def self.next_port
		offset = 1024
		return rand(2**16 - offset) + offset
	end

	def self.client()
		pproc = ProtoProc.new

		pproc.init do
			@src_port = next_port()
			send_msg(Msg.new(
				:op_code =>	OPCODE,
				:addr => Msg::Addr.new(
					:ip => @local_info.ipv4.to_i,
					:port => @src_port
				)
			))

			trans_null()
		end

		pproc.on_recv :init do |msg|
			if msg.check(:opcode => OPCODE)
				if msg.ip == 0 || !(1025..(2**16-1)).include?(msg.port)
					proto_error("invalid ip or port: #{msg.inspect}")
				else
					begin
						tcpsock = Timeout.timeout(15) {TCPSocket.new(
							IPaddr::from_int(msg.ip), 
							msg.port, 
							"0.0.0.0",
							@src_port
						)}
						success(tcpsock)
					rescue Errno::ECONNREFUSED => e
						failure(e.inspect)
					end
				end
			else
				proto_error("unexpected response: #{msg.inspect}")
			end
		end
	end
end

end