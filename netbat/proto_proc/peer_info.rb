require 'netbat/proto_proc'
require 'netbat/local_info'
require 'netbat/msg'

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
			if msg.error?
				if msg.err_type == Msg::ErrType::PEER_UNAVAILABLE
					std_err(ProtoProc::PeerUnavailable.new("peer is unavailable"))
				else
					proto_error("unexpected error: (#{msg.err_type.inspect}) #{msg.err.inspect}")
				end
			elsif msg.check(:op_code => OPCODE)
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