require 'netbat/log'
require 'netbat/netif'

module Netbat

module Tun
	# Linux 2.6.17: from /usr/include/linux/if_tun.h
    SETIFF		= 0x400454ca
	IFF_TUN		= 0x0001
	IFF_NO_PI	= 0x1000

	def self.open(*args, &bloc)
		Kernel.open("/dev/net/tun", "w+") do |tun|

			ifr = [ "nbtun#{rand(256)}", IFF_TUN|IFF_NO_PI ].pack("a16S")
			tun.ioctl(SETIFF, ifr)
			ifname = ifr[0, 16].gsub(/\x00/, "")
		
			configure(ifname, tun, *args)
			bloc.call(tun, ifname)
		end
	end

	def self.configure(ifname, tun, *options)
		ifc = Netif::Base.new(tun, ifname)
		
		options.each do |opt|
			next if !opt.is_a?(Hash)
			opt.each do |k,v|
				case k
				when :addr
					addr = Socket.sockaddr_in(0, v)
					ifc.set_addr(addr)
				when :mask
					ifc.set_mask(v)
				end
			end			
		end

		ifc.set_up
	end

end

end #Netbat