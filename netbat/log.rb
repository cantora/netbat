require 'logger'

module Netbat

	def self.ansi_color(str, code)
		return "\e[#{code}m#{str}\e[0m"
	end

	def self.ansi_yellow(str)
		return ansi_color(str, 33)
	end

	def self.thread_list()
		Thread.list.map do |thr|
			"#{thr.object_id.to_s(16)}: #{thr.status.inspect}"
		end.join(", ")
	end

	def self.exception_str(msg, e)
		return "#{msg}: (#{e.class.inspect}) #{e.message}\n#{e.backtrace.join("\n\t")}"
	end

	LOG = Logger.new($stderr)
	LOG.formatter = proc do |sev, t, pname, msg|
		sprintf(
			"#{sev[0..0]}#{ansi_yellow("[%s]:%s:")}%s\n", 
			t.strftime("%y-%m-%d %H:%M:%S"), 
			Thread.current.object_id.to_s(16), 
			msg
		)
	end

end