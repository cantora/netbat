require 'netbat/log'
require 'netbat/datagram/socket'
require 'netbat/common'

require 'blather/client/client'
require 'nokogiri'
require 'uri'

module Netbat::Datagram

class XMPPSocket < Socket
	attr_reader :password, :addr

	class XMPPAddr < Addr

		attr_reader :node, :domain, :resource
		
		def initialize(node, domain, resource)
			@node = node
			@domain = domain
			@resource = resource.gsub(/^\/*/, "")

			{:node => @node, :domain => @domain, :resource => @resource}.each do |k,v|
				if !v.is_a?(String) || v.empty?
					raise ArgumentError.new, "invalid #{k}: #{v.inspect}"
				end
			end
		end
		
		def to_s
			s = "#{@node}@#{@domain}"
			if @resource.size > 0
				s << "/" 
				s << @resource
			end

			return s
		end

		def self.from_uri(uri)
			return self.new(uri.user, uri.host, uri.path)
		end

		def self.uri_to_addr_and_auth(uri)
			Netbat::assert_uri(uri)
	
			user = uri.user
			password = uri.password
			domain = uri.host
			resource = uri.path
			{:user => user, :password => password, :domain => domain}.each do |k,v|
				raise ArgumentError.new, "invalid #{k} in uri: #{v.inspect}" if v.nil? || v.empty?
			end
	
			addr = self.new(user, domain, resource)
			return addr, password
		end
	end

	def initialize(addr, password)
		#Blather.logger.level = Logger::DEBUG
		
		@addr = addr
		@password = password
		init_client()
		@thr = nil
		@log = Netbat::LOG

		@recv_handler = nil
		@bind_handler = nil
		@close_hander = nil
	end

=begin
	def client_handler(*args, &bloc)
		#blather doesnt handle the case where 
		#we clear a handler when it doesnt exist yet, and i 
		#dont see a way to test for existence of a handler in the API.
		#thus we have to create one, then delete all, then create one
		@client.register_handler(*args, &bloc)

		@client.clear_handlers(*args)
		@client.register_handler(*args, &bloc)
	end
=end

	def init_client
		@client = Blather::Client.setup(self.xmpp_id, @password)
		@client.register_handler :subscription, :request? do |s|
			@log.debug("subsc(#{self.xmpp_id}):#{s.inspect}")
			@client.write s.approve!
		end

		@client.register_handler :message, :normal?, :body do |m|
			@log.debug("recv(#{self.xmpp_id}):#{m.from.inspect}, body=#{m.body.inspect}")

			if !@recv_handler.nil?
				@recv_handler.call(
					m.body, 
					XMPPAddr.from_uri(URI.parse("xmpp://#{m.from}") )
				)
			end
		end

		@client.register_handler :message, :error? do |m|
			doc = Nokogiri::XML.parse(m.to_s)
			err_code = doc.at_xpath("/message/error/@code")
			raise "expected to find valid error code: #{doc.to_xml.inspect}" if err_code.nil? || err_code.value.to_i <= 0
			
			@log.debug("recv_err(#{self.xmpp_id}):#{m.from.inspect}, error=#{doc.to_xml.inspect}")

			err_obj = case err_code.value.to_i
			when 503
				Socket::PeerUnavailable.new(doc.to_xml)
			else
				Socket::Error.new(doc.to_xml)
			end

			if !@recv_err_handler.nil?
				@recv_err_handler.call(
					err_obj,
					XMPPAddr.from_uri(URI.parse("xmpp://#{m.from}") )
				)
			end
		end

		@sent_signal = false
		@client.register_handler(:ready) do
			@log.debug("bound(#{self.xmpp_id})")
			if @sent_signal
				raise "already sent signal!"
			end

			@bind_mutex.synchronize do
				@bind_cv.signal
			end
			
			@client.status = :available
			if !@bind_handler.nil?
				@bind_handler.call()
			end
		end

		@client.register_handler(:disconnected) do
			@log.debug("closed(#{self.xmpp_id})")
			if !@close_handler.nil?
				@close_handler.call()
			end
		end
	end

	def xmpp_id
		return self.addr.to_s
	end

	def on_recv(&bloc)
		@recv_handler = bloc
	end

	def on_err(&bloc)
		@recv_err_handler = bloc
	end

	def on_subscription(&bloc)
		raise "not implemented"
	end

	def bound?
		return !@thr.nil?
	end

	def bind
		raise "endpoint is already bound!" if !@thr.nil?

		ready = false
		@thr = Thread.new do
			Thread.current.abort_on_exception = true
			@log.debug "xmpp socket start client"
			EventMachine.run { 
				@client.run
			}
		end

		@bind_cv = ConditionVariable.new
		@bind_mutex = Mutex.new
		@bind_mutex.synchronize do
			@bind_cv.wait(@bind_mutex)
		end

		return
	end

	def on_bind(&bloc)
		@bind_handler = bloc
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
		@close_handler = bloc
	end

	def send_msg(addr, msg)
		@log.debug "send_msg #{addr.to_s}: #{msg.inspect}"
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