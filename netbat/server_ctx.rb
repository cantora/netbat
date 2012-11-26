require 'netbat/datagram'

require 'base64'

['peer_info'].each do |fname|
	require File.join('netbat', 'proto_proc', fname)
end

module Netbat

class ServerCtx < Datagram::ConnectionCtx

	OPCODE_TO_PROC = {
		Msg::OpCode::INFO => PeerInfo.method(:server)
	}

	#gets called at regular intervals to provide cycles for internal maintenance
	def clock()
		current_proc_lock do 
			if !@current_proc.nil?
				result = begin
					if !@current_proc.status().nil? #procedure is finished
						@current_proc = nil
					end
				rescue ProtoProcException => e
					@log.warn "procedure #{@current_proc.inspect} raised exception: #{e.inspect}"
					@current_proc = nil
				end
			end
		end
	end

	def start_proc(d_msg)
		if OPCODE_TO_PROC.key?(d_msg.op_code)
			@log.debug log_str("start procedure for op code #{d_msg.op_code.inspect}")
			result = OPCODE_TO_PROC[d_msg.op_code].call(self, @local_info)
			#@log.debug log_str("procedure: #{result.inspect}")
			
			result.startup()
			return result
		else
			@log.debug log_str("no procedure for op code #{d_msg.op_code.inspect}. ignore message: #{d_msg.inspect}")
			return nil
		end
	end

	def recv(msg)
		current_proc_lock do
			if @current_proc.nil?
				dm = decode_message(msg)
				@current_proc = start_proc(dm)
			end
		end

		super(msg)	
	end

end

end