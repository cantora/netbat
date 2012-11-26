require 'netbat/proto_proc'
require 'netbat/local_info'
require 'netbat/protobuf/netbat.pb'

module Netbat

class PeerInfo < ProtoProcDesc

	register(self)

	OPCODE = Netbat::Msg::OpCode::INFO

	def self.client(ctx, local_info)
		pproc = ProtoProc.new(ctx)
		
		pproc.init do 
			send_msg(Msg.new(
				:op_code => Msg::OpCode::INFO,
				:host_type => local_info.host_type
			))

			trans_null()
		end

		pproc.on_recv :init do |msg|
			if check_msg(:host_type, :supported_ops, :opcode => OPCODE)
				success(
					LocalInfo.new(
						msg.host_type,
						msg.supported_ops
					)
				)
			else
				proto_error("unexpected response: #{msg.inspect}")
			end
		end

		return pproc
	end #client

	def self.server(local_info)
		
	end

end

end #Netbat