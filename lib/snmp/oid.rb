module Snmp
  # SnmpOid is a sortable numeric OID string
  class Oid
    include Comparable

    attr_reader :oidstr, :cmpstr

    def initialize(oidstr)
      @oidstr = oidstr
      @cmpstr = oidstr.split(/\./).reject {|x| x==''}.map { |x| '%08X' % x }.join(".")
    end

    def <=>(other)
      @cmpstr <=> other.cmpstr
    end

    def hash
      oidstr.hash
    end

    def eql?(other)
      oidstr == other.oidstr
    end

    def to_s
      @oidstr
    end
  end
end