require 'netbat/datagram'
require 'netbat/proto_proc'

require 'base64'

['INFO', 'BF0'].each do |fname|
	require File.join('netbat', 'proto_proc', fname)
end

module Netbat

class ClientCtx < Datagram::ConnectionCtx

	def run_proto_proc(pproc)
		@current_proc = pproc
		return @current_proc.run()
	end

	def loop()
		peer_info = run_proto_proc(INFO::client(self, @local_info) )

		@log.debug "local_info: #{@local_info.inspect}"
		@log.debug "peer_info: #{peer_info.inspect}"
		
		result = nil
		ProtoProcDesc::procedures.select {|x| x.ancestors.include?(PunchProcDesc) }.each do |ppd|
			@log.info "attempt to punch tcp cx via #{ppd.inspect}"
			if ppd.supports?(@local_info.host_type, peer_info.host_type)
				result = run_proto_proc(ppd.client(self, @local_info))
				break if result.is_a?(TCPSocket)
			end
		end

		if result.is_a?(TCPSocket)
			@log.info "success: #{result.inspect}"
		else
			@log.info "failure: #{result.inspect}"
		end
	end

end

end