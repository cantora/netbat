require 'netbat/log'

module Netbat

module Tun
	# Linux 2.6.17: from /usr/include/linux/if_tun.h
    SETIFF		= 0x400454ca
	IFF_TUN		= 0x0001
	IFF_NO_PI	= 0x1000

	def self.open(&bloc)
		Kernel.open("/dev/net/tun", "w+") do |tun|

			ifr = [ "", IFF_TUN|IFF_NO_PI ].pack("a16S")
			ifr += "nbtun#{rand(256)}"
			tun.ioctl(TUNSETIFF, ifr)
			ifname = ifr[0, 16].gsub(/\x00/, "")
		
			bloc.call(tun, ifname)
		end
	end

end

end #Netbat