require 'netbat/datagram'
require 'netbat/proto_proc'

require 'base64'

['INFO', 'HP0', 'HP1'].each do |fname|
	require File.join('netbat', 'proto_proc', fname)
end

module Netbat

class ServerCtx < Datagram::ConnectionCtx

	#when the server receives a message from a client
	#with which it is not currently executing a procedure,
	#it looks at this table to see what code it should
	#use to execute the procedure
	OPCODE_TO_PROC = {
		Msg::OpCode::INFO => INFO.method(:server),
		Msg::OpCode::HP0 => HP0.method(:server),
		Msg::OpCode::HP1 => HP1.method(:server)
	}

	#gets called at regular intervals to provide cycles for internal maintenance
	def clock()
		return current_proc_lock do 
			if !@current_proc.nil?
				begin
					#check to see if current procedure has finished or failed
					stat = @current_proc.status()
					if !stat.nil? #procedure is finished
						@current_proc = nil
					end
					stat
				rescue ProtoProc::ProtoProcException => e
					@log.warn "procedure raised exception: #{e.inspect}"
					@current_proc = nil
					nil
				end
			end
		end
	end

	def start_proc(d_msg)
		#lookup method to use for this opcode
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

	#dispatch received messages to current procedure
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