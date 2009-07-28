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
      @refresh_interval = args[:refresh_interval] || false
      @prep = block
    end

    def dump
      set = triple_set
      put_lines set.triples
      put_lines "."
    end

    def get_line
      l = begin
        Timeout::timeout(@idle_timeout) { @in_fh.gets }
      rescue Timeout::Error
        @logger.debug "Agent idle timeout after #{@idle_timeout} seconds"
        exit
      end

      if l.nil?
        @logger.debug("> <eof>")
        return nil
      end
      l.chomp!
      @logger.debug("> #{l}")
      l
    end

    def put_lines(s)
      s.each { |x| 
        logger.debug("< #{x.to_s}")
        @out_fh.print "#{x.to_s}\n"
      }
      @out_fh.flush
    end

    def put_triple(t)
      put_lines [ t.oid, t.type, t.value ]
    end

    def triple_set
      @triple_set || populate_triple_set
    end

    def get(oid, message = "get")
      triple = triple_set.send(message, oid)

      if triple.nil?
        put_lines "NONE"
      else
        put_triple(triple)
      end
    end

    def get_next(oid)
      get oid, "getnext"
    end

    def run
      @logger.debug("Agent starting")

      @logger.debug("Loading initial values")
      populate_triple_set
      @logger.debug("Loaded #{@triple_set.triples.size} values")

      if @refresh_interval
        @logger.debug("Launching refresh thread")
        Thread.new do
          sleep @refresh_interval
          @logger.debug("Refreshing triple set")
          populate_triple_set
          @logger.debug("Loaded #{@triple_set.triples.size} values")
        end
        @logger.debug("Launched refresh thread")
      end

      quit = false

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
          get(SnmpOid.new(get_line))
        when /^getnext$/i
          get_next(SnmpOid.new(get_line))
        when /^set$/i
          ignore = get_line
          put_lines "not-writable"

          # Additional commands not used by snmpd
        when /^(exit|quit)$/i
          put_lines "BYE"
          quit = true
          @logger.debug("Agent asked to quit (#{l})")
        when /^dump$/i
          dump
        else
          put_lines "unknown-command"
        end
      end
      @logger.debug("Agent exiting")
    end

    private
    def populate_triple_set
      set = SnmpTripleSet.new
      @prep.call(set)
      set.make_index
      @triple_set = set
    end
  end
end