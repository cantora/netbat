require 'netbat/proto_proc'
require 'netbat/peer_info'
require 'netbat/msg'

module Netbat

class INFO < ProtoProcDesc

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
					PeerInfo.new(
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

	def self.server(ctx, local_info)
		pproc = ProtoProc.new(ctx)
		
		pproc.on_recv :init do |msg|
			@log.debug "peer info msg: #{msg.inspect}"
			if msg.error?
				proto_error("error: (#{msg.err_type.inspect}) #{msg.err.inspect}")
			elsif msg.check(:op_code => OPCODE)
				send_msg(Msg.new(
					:op_code => OPCODE,
					:host_type => local_info.host_type,
					:supported_ops => local_info.supported_ops
				))
				
				success(true)
			else
				proto_error("ignoring unexpected message: #{msg.inspect}")
			end
		end
				
		return pproc
	end

end

end #Netbat