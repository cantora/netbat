require 'netbat/datagram'

require 'base64'

['peer_info', 'both_filtered0'].each do |fname|
	require File.join('netbat', 'proto_proc', fname)
end


module Netbat

class ClientCtx < Datagram::ConnectionCtx

	def run_proto_proc(pproc)
		@current_proc = pproc
		return @current_proc.run()
	end

	def loop()
		peer_info = run_proto_proc(PeerInfo::client(self, @local_info) )

		@log.debug "peer_info: #{peer_info.inspect}"
		
		ProtoProcDesc::procedures.select {|x| x.is_a?(PunchProtoDesc) }.each do |ppd|
			@log.info "attempt to punch tcp cx via #{ppd.inspect}"
			run_proto_proc(ppd.client(self, @local_info))
		end
	end

end

end