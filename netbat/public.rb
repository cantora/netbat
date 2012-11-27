require 'uri'
require 'timeout'
require 'open-uri'
require 'ipaddr'
require 'nokogiri'

module Netbat

module Public

	class DiscoveryException < Exception; end
	class InvalidAddr < DiscoveryException; end

	def self.ipv4
		result = begin
			Timeout::timeout(5) do 
				open(URI.parse('http://ipecho.net/plain')).read
			end
		rescue SocketError, Timeout::Error => e
			raise DiscoveryException.new, "failed to discover ipv4 addr: #{e.inspect}"
		end
		
		return str_to_ipv4_addr(result)
	end

	def self.str_to_ipv4_addr(str)
		begin
			IPAddr.new(str, Socket::PF_INET)
		rescue ArgumentError => e
			raise InvalidAddr.new, "invalid address: #{e.inspect}"
		end
	end

	def self.ipv4_port_test(port)
		require 'socket'

		u = URI.parse("http://www.dbc.uci.edu/cgi-bin/ipecho.pl")

		output = begin
			Timeout::timeout(6) do 
				sock = TCPSocket.new(u.host, 80, "0.0.0.0", port)
				getreq = "GET #{u.path} HTTP/1.0\r\n\r\n"
				#puts getreq.inspect
				sock.write(getreq)
				sock.read
			end
		rescue Timeout::Error => e
			raise DiscoveryException.new, "error reading from socket: #{e.inspect}"
		end

		headers, body = output.split("\r\n\r\n", 2)
		
		if !headers.match(/^HTTP\/1\.1\s+200\s+OK/)
			raise DiscoveryException.new, "http error: #{output}"
		end

		if body.nil? || body.strip.empty?
			raise DiscoveryException.new, "http body invalid: #{output}"
		end

		doc = Nokogiri::HTML.parse(body)
		#puts doc.to_html

		addr = doc.at_xpath('//body/dl/dt/b[contains(text(), "REMOTE_ADDR")]/../following-sibling::dd/i')
		raise DiscoveryException.new, "failed to extract address: #{doc.to_html}" if addr.nil?
		#puts addr.inner_text.to_s
		addr = str_to_ipv4_addr(addr.inner_text.to_s)

		port = doc.at_xpath('//body/dl/dt/b[contains(text(), "REMOTE_PORT")]/../following-sibling::dd/i')
		raise DiscoveryException.new, "failed to extract port: #{doc.to_html}" if port.nil? 
		#puts port.inner_text.to_s
		ptxt = port.inner_text
		if !(1..(2**16-1)).include?(ptxt.to_i)
			raise DiscoveryException.new, "extracted invalid port #{ptxt}: #{doc.to_html}" 
		end
		port = ptxt.to_i
		
		return addr, port
	end
	
end

end #Netbat
