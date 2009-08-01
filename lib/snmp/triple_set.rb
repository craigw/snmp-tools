module Snmp
  # SnmpTripleSet represents an indexed set of SnmpTriple objects, e.g. for
  # an OID sub-tree
  #
  class TripleSet
    # All Triples in this set.
    #
    attr_reader :triples

    def initialize(options = {})
      @base_oid = options[:base_oid]
      @triples = []
    end

    # Add a triple to the set
    #
    def push(*args)
      if args.size == 1 && args.first.kind_of?(Triple)
        t = args.pop
        if t.oid.oidstr =~ /^#{@base_oid}/
          @triples.push(t)
        else
          raise "Triple `#{t.oidstr}` did not belong to base OID of TripleSet `#{@base_oid}`."
        end
      elsif args.size == 3
        @triples.push(Triple.new(@base_oid.to_s + args[0], args[1], args[2]))
      else
        raise ArgumentError, "TripleSet#push takes either 1 Triple or a tuple of (OID String, Data Type, Value) as arguments."
      end
    end

    # Build the triple set index so it's easy to get the previous / next OID
    # in the series.
    #
    def make_index
      @triples.sort!

      @index = {}
      @triples.each { |x| @index[x.oid] = x }
    end

    # Get the Triple that has OID +oid+.
    #
    def get(oid)
      @index[oid]
    end

    # Get the Triple that comes after OID +oid+.
    #
    def getnext(oid)
      @triples.each { |x| return x if x.oid > oid }
      nil
    end
  end
end