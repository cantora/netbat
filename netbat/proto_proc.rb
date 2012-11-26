module Netbat

class ProtoProcDesc

	@@procedures = []

	def self.register(klass)
		@@procedures << klass
	end
end

class PunchProcDesc < ProtoProcDesc
	def self.supports?(my_type, peer_type)
		return false
	end
end

class ProtoProc
	
	RESERVED_STATES = [
		:init, 
		:failure, 
		:success, 
		:proto_error,
		:timeout
	]

	attr_reader :state

	def initialize(ctx, *args)
		@ctx = ctx
		@state = :start
		@state_mtx = Mutex.new
		
		@on_entry = {}
		@on_recv = {}
		@log = Netbat::LOG
		@history = []
		@idle_timeout = 5 #seconds
		
		args.each do |arg|
			next if !arg.is_a?(Hash)
			arg.each do |k,v|
				case k
				when :idle_timeout
					@idle_timeout = v
				end
			end
		end

		update_last_transition()
	end

	def update_last_transition
		@last_transition = Time.now.to_i
	end

	def on_entry(state, &bloc)
		@on_entry[:init] = bloc
	end

	def init(&bloc)
		on_entry(:init, &bloc)
	end

	def on_recv(state, &bloc)
		@on_recv[state] = bloc
	end

	Transition = Struct.new(:next, :user)
	NullTransition = :null_transition

	def trans_null()
		return NullTransition
	end

	def trans(state, user=nil)
		return Transition.new(state, user)
	end

	def success(output)
		return trans(:success, output)
	end

	def failure(msg)
		return trans(:failure, msg)
	end

	def proto_error(msg)
		return trans(:proto_error, msg)
	end

	def timeout(msg)
		return trans(:timeout, msg)
	end
	#must have a lock on @state in this function
	def terminated?
		return [:success, :failure, :proto_error, :timeout].include?(@state)
	end

	def recv(msg)
		@state_mtx.synchronize do
			if !terminated? && on_recv.key?(@state)
				result = instance_exec(msg, &on_recv[@state])
				if !result.is_a?(Transition)
					raise "expected a transition object from callback"	
				end

				if result != NullTransition
					make_transition(result)
				end
			else
				@log.info "dropped msg: #{msg.inspect}"
			end
		end
	end

	def send_msg(msg)
		@ctx.send_msg(msg)
	end

	#must have a lock on @state while in this function
	def run_on_entry()
		if @on_entry.key?(@state)
			instance_exec(&@on_entry[@state])
		end
	end

	#must have a lock on @state while in this function
	def make_transition(tr)
		return if tr == NullTransition
		@history << tr
		@log.debug "transition: #{@state} => #{tr.next}"
		raise "invalid state: #{@state.inspect}" if !@state.is_a?(Symbol)
		raise "invalid state: #{tr.next.inspect}" if !tr.next.is_a?(Symbol)
		@state = tr.next
		run_on_entry()
		update_last_transition()
	end

	class ProtoProcException < Exception; end
	class ProcedureFailed < ProtoProcException; end
	class ProtocolFailed < ProtoProcException; end
	class Timeout < ProtocolFailed; end

	def run()
		if @state != :start
			raise "current state is not :start"
		end

		@state_mtx.synchronize do
			make_transition(trans(:init))
		end

		loop do 
			#dont need to lock here b.c. if @state is one of these we are terminated
			case @state
			when :success
				return @history.last.user
			when :failure
				raise ProcedureFailed.new, @history.last.user
			when :proto_error
				raise ProtocolFailed.new, @history.last.user
			when :timeout
				raise Timeout.new, @history.last.user
			end

			if (Time.now.to_i - @last_transition) > @idle_timeout
				@state_mtx.synchronize do 
					#make sure its still true
					if (Time.now.to_i - @last_transition) > @idle_timeout
						make_transition(timeout("idle timeout exceeded"))
					end
				end
			end

			sleep(0.1)
		end		
	end

end



end #Netbat