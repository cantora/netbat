
module Netbat

def self.assert_uri(uri)
	if !uri.is_a?(URI)
		raise ArgumentError.new, "expected URI class, got: #{uri.inspect}"
	end
end

def self.assert_str(str)
	if !str.is_a?(String) || str.empty?
		raise ArgumentError.new, "expected non-empty string, got: #{str.inspect} (#{str.class.inspect})"
	end
end

end #Netbat