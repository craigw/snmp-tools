module Snmp
  # This implements the agent end of the pass_persist protocol. Below is a
  # brief descrption of the protocol as described in the snmpd man page.
  #
  #   Upon initialization, PROG will be passed the string "PING\n" on stdin,
  #   and should respond by printing "PONG\n" to stdout.
  #
  #   For GET and GETNEXT requests, PROG will be passed two lines on stdin,
  #   the command (get or getnext) and the requested OID. It should respond
  #   by printing three lines to stdout - the OID for the result varbind, the
  #   TYPE and the VALUE itself - exactly as for the pass directive above. If
  #   the command cannot return an appropriate varbind, it should print 
  #   "NONE\n" to stdout (but continue running).
  #
  #   For SET requests, PROG will be passed three lines on stdin, the command
  #   (set) and the requested OID, followed by the type and value (both on the
  #   same line). If the assignment is successful, the command should print
  #   "DONE\n" to stdout. Errors should be indicated by writing one of the
  #   strings not-writable, wrong-type, wrong-length, wrong-value or
  #   inconsistent-value to stdout, and the agent will generate the
  #   appropriate error response. In either case, the command should continue
  #   running.
  #
  # Note that agents which write values are not currently supported and that
  # the agents will just return a "not-writeable" response as described above.
  # If you need this functionality patches would be considered. It wouldn't be
  # hard to add, I just haven't had that itch.
  #
  class PassPersistAgent
    def initialize(args = {}, &block)
      @logger = args[:logger] || Logger.new("/dev/null")
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

    def get_line
      l = Timeout::timeout(@idle_timeout) { @in_fh.gets }
      if l.nil?
        @logger.debug("> <eof>")
        return nil
      end
      l.chomp!
      @logger.debug("> "+l)
      l
    end

    def put_lines(s)
      s.each { |x| 
        logger.debug("< "+x.to_s)
        @out_fh.print x.to_s+"\n"
      }
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
      @logger.debug("Agent starting")
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
      @logger.debug("Agent exiting")
    end
  end
end