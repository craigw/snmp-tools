module Snmp
  # SnmpTripleSet represents an indexed set of SnmpTriple objects, e.g. for
  # an OID sub-tree
  #
  class TripleSet
    def initialize
      @triples = []
    end

    # Add a triple to the set
    #
    def push(t)
      @triples.push(t)
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

    # Get all Triples in the set.
    #
    def triples
      @triples
    end
  end
end