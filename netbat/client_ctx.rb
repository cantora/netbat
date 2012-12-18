require 'netbat/datagram'
require 'netbat/proto_proc'

require 'base64'

['INFO', 'HP0', 'HP1'].each do |fname|
	require File.join('netbat', 'proto_proc', fname)
end

module Netbat

#class to manage the connection state between
#a client and a server
class ClientCtx < Datagram::ConnectionCtx

	def run_proto_proc(pproc)
		#need to maintain which procedure is 
		#currently running (see datagram.rb)
		@current_proc = pproc
		return @current_proc.run()
	end

	class AllProceduresFailed < Exception; end
	
	#run the procedures in procs against the server
	def run(procs)
		peer_info = run_proto_proc(INFO::client(self, @local_info) )

		@log.debug "local_info: #{@local_info.inspect}"
		@log.debug "peer_info: #{peer_info.inspect}"
		
		result = nil
		procs.each do |ppd|
			@log.info "attempt to punch udp cx via #{ppd.inspect}"

			#only run procedures that match the local/peer host types
			if ppd.supports?(@local_info.host_type, peer_info.host_type)
				result = begin
					run_proto_proc(ppd.client(self, @local_info))
				rescue ProtoProc::StandardException => e
					@log.warn "#{ppd} threw exception: #{e.message}. continuing..."
					nil
				end
				break if result.is_a?(PunchProcDesc::PunchProcResult)
			else
				@log.info "  #{ppd} does not support host types"
			end
		end

		if result.is_a?(PunchProcDesc::PunchProcResult)
			@log.info "success: #{result.inspect}"
			return result
		else
			@log.info "failure: #{result.inspect}"
			raise AllProceduresFailed.new, "all failed: #{procs.map {|x| x.to_s}.join(", ")}"
		end
	end

end

end