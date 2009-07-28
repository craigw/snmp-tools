module Snmp
  # A tuple of (Snmp::Oid, SNMP type, value).
  #
  class Triple
    attr_reader :oid, :type, :value

    def initialize(oid, type, value)
      case type
      when /^(string|integer|unsigned|objectid|timeticks|ipaddress|counter|gauge)$/
        nil
      else
        raise "Bad SNMP type '%s'" % type
      end

      oid = Snmp::Oid.new(oid) unless oid.kind_of?(Snmp::Oid)

      @oid = oid
      @type = type
      @value = value
    end

    def <=>(other)
      @oid <=> other.oid
    end

    def to_s
      "#{@oid} = #{@type}: #{value}"
    end

    def value
      @value.respond_to?(:call) ? @value.call : @value
    end
  end
end