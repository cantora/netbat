require 'netbat/proto_proc'
require 'netbat/protobuf/netbat.pb'

require 'socket'

module Netbat

#simplest firewall hole punch with no TCP state trickery
#should not require super user privs on either side
class BothFiltered0 < ProtoProcDesc
	
	def self.supports?(my_type, peer_type)
		if my_type == Punch::HostType::Filter \
				&& peer_type == Punch::HostType::Filter
			return true
		end

		return false
	end

	register(self)

	OPCODE = Netbat::Punch::OpCode::BF0

	def self.next_port
		offset = 1024
		return rand(2**16 - offset) + offset
	end

	def self.client()
		pproc = ProtoProc.new

		pproc.init do 
			send_msg(Netbat::Punch.new(
				:op_code =>	OPCODE,
				:addr => Netbat::Addr.new(
					:ip => Netbat::ip_addr_to_int(@local_info[:ip]),
					:port => next_port()
				)
			))

			trans_null()
		end

		pproc.on_recv :init do |msg|
			if check_msg(:opcode => OPCODE, :ip, :port) 
				begin
					tcpsock = TCPSocket.new(Netbat::int_to_ip_addr(msg.ip), msg.port)
					success(tcpsock)
				rescue Errno::ECONNREFUSED => e
					failure(e.inspect)
				end	
			else
				proto_error("unexpected response: #{msg.inspect}")
			end
		end
	end
end

end