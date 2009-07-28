# This implements the agent end of the pass_persist protocol
module Snmp
  class PassPersistAgent
    def initialize(args = {}, &block)
      @in_fh = args[:in_fh] || STDIN
      @out_fh = args[:out_fh] || STDOUT
      @idle_timeout = args[:idle_timeout] || 60

      if block_given?
        @prep = block
      else
        @prep = args[:prepare_responses]
      end
      @get = args[:get]
      @getnext = args[:getnext]
    end

    def dump
      set = SnmpTripleSet.new
      @prep.call(set)
      set.make_index
      put_lines set.triples
      put_lines "."
    end

    def log(s)
    end

    def get_line
      l = Timeout::timeout(@idle_timeout) { @in_fh.gets }
      if l.nil?
        log("> <eof>")
        return nil
      end
      l.chomp!
      log("> "+l)
      l
    end

    def put_lines(s)
      s.each { |x| log("< "+x.to_s) }
      s.each { |x| @out_fh.print x.to_s+"\n" }
      @out_fh.flush
    end

    def put_triple(t)
      put_lines [ t.oid, t.type, t.value ]
    end

    def do_prepare
      set = SnmpTripleSet.new
      @prep.call(set)
      set.make_index
      set
    end

    def _do_get(oid, hook, message)
      if not hook.nil?
        triple = hook.call(oid)
      elsif not @prep.nil?
        ts = do_prepare
        triple = ts.send(message, oid)
      else
        raise "Can't " + message
      end

      if triple.nil?
        put_lines "NONE"
      else
        put_triple(triple)
      end
    end

    def do_get(oid)
      _do_get oid, @get, "get"
    end

    def do_getnext(oid)
      _do_get oid, @getnext, "getnext"
    end

    def run
      quit = false

      begin
        while not quit
          l = get_line
          break if l.nil?

          case l
            # snmpd doesn't need these commands to be
            # case-insensitive; I've made them that way for easier
            # debugging
          when /^ping$/i
            put_lines "PONG" 
          when /^get$/i
            do_get(SnmpOid.new(get_line))
          when /^getnext$/i
            do_getnext(SnmpOid.new(get_line))
          when /^set$/i
            ignore = get_line
            put_lines "not-writable"

            # Additional commands not used by snmpd
          when /^(exit|quit)$/i
            put_lines "BYE"
            quit = true
          when /^dump$/i
            dump
          else
            put_lines "unknown-command"
          end
        end
      rescue Timeout::Error
      end
    end
  end
end