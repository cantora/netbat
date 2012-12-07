require 'netbat/datagram'
require 'netbat/proto_proc'

require 'base64'

['INFO', 'HP0'].each do |fname|
	require File.join('netbat', 'proto_proc', fname)
end

module Netbat

class ClientCtx < Datagram::ConnectionCtx

	def run_proto_proc(pproc)
		@current_proc = pproc
		return @current_proc.run()
	end

	class AllProceduresFailed < Exception; end
	
	def run(procs)
		peer_info = run_proto_proc(INFO::client(self, @local_info) )

		@log.debug "local_info: #{@local_info.inspect}"
		@log.debug "peer_info: #{peer_info.inspect}"
		
		result = nil
		#ProtoProcDesc::procedures.select {|x| x.ancestors.include?(PunchProcDesc) }.each do |ppd|
		procs.each do |ppd|
			@log.info "attempt to punch udp cx via #{ppd.inspect}"
			if ppd.supports?(@local_info.host_type, peer_info.host_type)
				result = begin
					run_proto_proc(ppd.client(self, @local_info))
				rescue ProtoProc::StandardException => e
					@log.warn "#{ppd.class} threw exception: #{e.message}. continuing..."
					nil
				end
				break if result.is_a?(UDPSocket)
			else
				@log.info "  #{ppd.class} does not support host types"
			end
		end

		if result.is_a?(UDPSocket)
			@log.info "success: #{result.inspect}"
			return result
		else
			@log.info "failure: #{result.inspect}"
			raise AllProceduresFailed.new, "all failed: #{procs.map {|x| x.class.to_s}.join(", ")}"
		end
	end

end

end