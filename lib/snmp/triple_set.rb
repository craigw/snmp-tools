module Snmp
  # SnmpTripleSet represents an indexed set of SnmpTriple objects, e.g. for
  # an OID sub-tree
  class TripleSet
    def initialize
      @triples = []
    end

    def push(t)
      @triples.push(t)
    end

    def make_index
      @triples.sort!

      @index = {}
      @triples.each { |x| @index[x.oid] = x }
    end

    def get(oid)
      @index[oid]
    end

    def getnext(oid)
      @triples.each { |x| return x if x.oid > oid }
      nil
    end

    def triples
      @triples
    end
  end
end