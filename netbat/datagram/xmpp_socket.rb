require 'netbat/log'
require 'netbat/datagram/socket'
require 'netbat/common'

require 'blather/client/client'
require 'uri'

module Netbat::Datagram

class XMPPSocket < Socket
	attr_reader :password, :addr

	class XMPPAddr < Addr

		def initialize(val)
			super(val.to_s)
			Netbat::assert_str(@val)
			@uri = URI.parse(@val)
		end
		
		def to_s
			return "#{@uri.user}@#{@uri.host}/#{@uri.path}"
		end

		def domain
			return @uri.host
		end

		def node
			return @uri.user
		end

		def resource
			return @uri.path
		end
	end

	def initialize(uri)
		Netbat::assert_uri(uri)

		Blather.logger.level = Logger::DEBUG
		user = uri.user
		@password = uri.password
		domain = uri.host
		resource = uri.path
		{:user => user, :password => @password, :domain => domain}.each do |k,v|
			raise ArgumentError.new, "invalid #{k} in uri: #{v.inspect}" if v.nil? || v.empty?
		end

		@addr = XMPPAddr.new("xmpp://#{user}@#{domain}/#{resource}")
		init_client()
		@thr = nil
		@log = Netbat::LOG

	end

	def client_handler(*args, &bloc)
		#blather doesnt handle the case where 
		#we clear a handler when it doesnt exist yet, and i 
		#dont see a way to test for existence of a handler in the API.
		#thus we have to create one, then delete all, then create one
		@client.register_handler(*args, &bloc)

		@client.clear_handlers(*args)
		@client.register_handler(*args, &bloc)
	end

	def init_client
		@client = Blather::Client.setup(self.xmpp_id, @password)
		client_handler :subscription, :request? do |s|
			@log.debug("subsc(#{self.xmpp_id}):#{s.inspect}")
			@client.write s.approve!
		end

		on_recv {}
		on_bind {}
		on_close {}
	end

	def xmpp_id
		return self.addr.to_s
	end

	def on_recv(&bloc)
		client_handler(:message) do |m|
			@log.debug("recv(#{self.xmpp_id}):#{m.from.inspect}, #{m.body.inspect}")
			bloc.call(
				m.body, 
				XMPPAddr.new(m.from)
			)
		end
	end

	def on_subscription(&bloc)
		raise "not implemented"
	end

	def bound?
		return !@thr.nil?
	end

	def bind
		raise "endpoint is already bound!" if !@thr.nil?

		@thr = Thread.new do
			Thread.current.abort_on_exception = true
			@log.debug "xmpp socket start client"
			EventMachine.run { 
				@client.run
			}
		end

		loop do
			break if @client.connected?
		end
		sleep(5)
		return
	end

	def on_bind(&bloc)
		client_handler(:ready) do
			@log.debug("bound(#{self.xmpp_id})")
			@client.status = :available
			bloc.call()
		end
	end

	def close
		raise "endpoint not bound" if @thr.nil?
		
		@log.debug "unbind"
		if @client.connected?
			@log.debug "close client (status = #{@client.status.inspect})"
			@client.close 
		else
			@log.debug "client not setup, kill thread"
			@thr.kill
		end

		@log.debug "join thread"
		@thr.join
		@log.debug "thread dead"
		init_client()
		@thr = nil
	end

	def on_close(&bloc)
		client_handler(:disconnected) do
			@log.debug("closed(#{self.xmpp_id})")
			bloc.call()
		end
	end

	def send(addr, msg)
		@log.debug "send #{addr.to_s}: #{msg.inspect}"
		@client.write Blather::Stanza::Message.new(addr.to_s, msg, :normal)
	end

	def subscribe(peer_addr)
		@log.warn "subscribe to peer #{peer_addr.to_s}"

		@client.register_tmp_handler(:stanza) do |thing|
			raise thing.inspect
		end

		@client.write Blather::Stanza::PubSub::Subscribe.new(
			:set, 
			peer_addr.domain, 
			peer_addr.node, 
			self.xmpp_id
		)

		@log.warn "wait for peer response"
		Thread.stop
		raise "asdf"
	end
end

end #Netbat::Datagram