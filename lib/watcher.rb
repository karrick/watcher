#! /usr/bin/env ruby

# Watcher
#
# Summary::   Watcher provides advanced integrated exception handling and
#             logging functionality to your Ruby programs.
# Author::    Karrick McDermott (karrick@karrick.org)
# Date::      2008-07-04
# Copyright:: Copyright (c) 2008 by Karrick McDermott.  All rights reserved.
# License::   Internet Systems Consortium (ISC) License (ISCL)

######################################################################

require 'event'

######################################################################
class Watcher

# module Watcher

  # :stopdoc:
  VERSION = '1.2.5'
  LIBPATH = ::File.expand_path(::File.dirname(__FILE__)) + ::File::SEPARATOR
  PATH = ::File.dirname(LIBPATH) + ::File::SEPARATOR
  # :startdoc:

  # Returns the version string for the library.
  #
  def self.version
    VERSION
  end

  # Returns the library path for the module. If any arguments are given,
  # they will be joined to the end of the libray path using
  # <tt>File.join</tt>.
  #
  def self.libpath( *args )
    args.empty? ? LIBPATH : ::File.join(LIBPATH, args.flatten)
  end

  # Returns the lpath for the module. If any arguments are given,
  # they will be joined to the end of the path using
  # <tt>File.join</tt>.
  #
  def self.path( *args )
    args.empty? ? PATH : ::File.join(PATH, args.flatten)
  end

  # Utility method used to require all files ending in .rb that lie in the
  # directory below this file that has the same name as the filename passed
  # in. Optionally, a specific _directory_ name can be passed in such that
  # the _filename_ does not have to be equivalent to the directory.
  #
  def self.require_all_libs_relative_to( fname, dir = nil )
    dir ||= ::File.basename(fname, '.*')
    search_me = ::File.expand_path(
        ::File.join(::File.dirname(fname), dir, '**', '*.rb'))

    Dir.glob(search_me).sort.each {|rb| require rb}
  end

  # Array of actions to perform when an Exception is thrown by code in the
  # yield block.
  # * The Watcher instance maintains a default @default_fail Hash for use when
  #   a given invocation does not specify a different set of actions to
  #   perform.
  # * The default value is a Hash with one key, the value of which causes
  #   Watcher to re-raise the exception if one should occur.
  attr_accessor :default_fail

  # A String to include inside the log entry when an Exception is thrown.
  # * This may be required in some circumstances where a separate log
  #   monitoring program is scanning log files looking for a string such as,
  #   ERROR or FAILURE.
  # * The default value is nil.
  attr_accessor :error_symbol

  # Tracks the number of times an Exception has invoked the :raise fail
  # action.
  # * Fail actions to log an error (:log), invoke a Proc (lambda {...}), and
  #   retry (:retry) are ignored because flow of the program is allowed to
  #   continue for each of those, whereas a :raise will abort processing of
  #   subsequent tasks until caught.
  # * If a title raises an Exception, but the title is enclosed in another title
  #   that merely logs the Exception, then the @errors attribute is still
  #   incremented.  This is useful for signalling when a warning condition
  #   occured, but the program is able to continue the processing of
  #   subsequent tasks.
  attr_reader :errors

  # A String of characters to use when joining multiple error lines into a
  # single line for output to the log.
  # * If nil, the Exception message is reported verbatim.  If not nil, the
  #   value must respond to the <tt>to_s</tt> method, which is used to join
  #   the Exception message lines.
  # * The default value is ' (LF) '.
  attr_accessor :merge_newlines

  # Holds a Proc object assigned the title of formatting the system time to a
  # String for display.
  # * You can easily change how the times are displayed by passing a Proc
  #   object or a block to this attribute.
  # * If you pass a block, be sure to wrap it with lambda.
  #
  #   <tt>$watcher.time_formatter( lambda { Time.now.utc } )</tt>
  #
  # * The default value is a Proc object that returns a String representing
  #   local time in the standard system format.
  attr_accessor :time_formatter

  # Determines level of reporting that Watcher object sends to the log file.
  # * Possible values are the set of values in the class attribute
  #   @@verbosity_levels.
  # * The default value is :always.
  attr_accessor :verbosity

  # Provide ability for Watcher to prioritize levels of verbosity.
  # * It wasn't designed to be directly used by client code, but I suppose it
  #   could be modified by consumer code in this script if the situation
  #   warranted.
  @@verbosity_levels =
    { :debug => 0, :verbose => 1, :always => 2, :quiet => 2 }

  # A String to include inside the log entry when an Exception is thrown.
  # * This may be required in some circumstances where a separate log
  #   monitoring program is scanning log files looking for a string such as,
  #   ERROR or FAILURE.
  # * The default value is nil.
  attr_accessor :warn_symbol

  # Tracks the number of times an Exception has been raised, regardless of
  # whether the Exception was re-thrown.
  attr_reader :warnings

  # We override the default accessibility for the :new method because we want
  # to ensure there is only one Watcher object created.
  private_class_method :new
  @@watcher = nil

  # #Watcher.create is the only way to instantiate a new Watcher object.
  # * You cannot use the #new method directly as you can with regular classes.
  # * Repeated calls to #Watcher.create simply return the same Watcher object.
  # * When a Watcher object is created, the default class initialization
  #   values are usually perfectly suitable for the title at hand.  This is
  #   more-so true when just starting on a new project, when the default is to
  #   send logging information to STDOUT, which is usually what you want when
  #   developing a program using the interactive method, such as with irb,
  #   or when running a process from the command shell.
  # * It is easy to change any of the class attributes either at object
  #   instantiation, or while the program is being executed. During
  #   instantiation simply create a Hash object with a key Symbol for every
  #   attribute you wish to change, whose value is your desired value.  For
  #   instance, to create a globabl variable, aptly named <tt>$watcher</tt>:
  #
  # <tt>
  # $watcher = Watcher.create(:default_fail=>:warn, :verbosity=>:always)
  # </tt>
  #
  # * Each Watcher object instance stores an IO object for buffering data to
  #   the output log.  This can either be a regular file, STDERR, STDOUT, or
  #   perhaps a FIFO or a pipe.  If you do not want to use STDOUT or a
  #   regular file, simply make the connection, and pass it to your Watcher
  #   instance.
  # * The default value of @output is an IO instance of STDOUT.
  def self.create(attributes={})
    @@watcher ||= new(attributes)
  end

  # Used to identify a low-level title during development.
  # * This is most frequently invoked without a block, in which case it simply
  #   appends the title start and stop messages to the log if the verbosity
  #   level is at :debug.
  # * Use this when in lieu of a group of 'puts' statements littered through
  #   your source code.
  # * See detailed decription for #monitor for how this method works.
  def debug(title, event_fail=@default_fail)
    monitor(title, :debug, block_given?, event_fail) { yield }
  end

  # Usually the method of choice for your general logging purpose
  # needs.
  # * I typcially use it at every level of the stack frame to track the
  #   progress of the program.
  # * I recommend using this for every level of program logic that you desire
  #   to track.
  # * See detailed decription for #monitor for how this method works.
  def verbose(title, event_fail=@default_fail)
    monitor(title, :verbose, block_given?, event_fail) { yield }
  end

  # Use this sparingly.  (User specifies this verbosity level so your program
  # will not show anything, unless there is an error.)
  def always(title, event_fail=@default_fail)
    monitor(title, :always, block_given?, event_fail) { yield }
  end

  # Each Watcher object instance can optionally send a copy of its
  # log file to a given email account.
  # * You might want to call this if there were any errors while completing
  #   your tasks.
  # * NOTE: It is the responsibility of the calling routine to send the logs
  #   to a file if you intend to send the email.
  #   $watcher = Watcher.create(:output=>log_file, ...)
  def send_email(email,subject)
    @output.flush    # flush the output buffer
    if File.file?(@output_path)
      system "mail -s '#{subject}' #{email} < '#{@output_path}'"
    else
      raise ArgumentError, "Cannot send log file as email because no log file was created"
    end
  end

  ########################################
  private
  ########################################

  # The Watcher#initialize method is called by the Watcher.new method as
  # normal, however because the Watcher.new method is a private method, the
  # only way to create a new Watcher object is to use the Watcher.create
  # method, which in turn invokes Watcher.new, which--finally--invokes
  # Watcher#initialize.
  def initialize(attributes={}) #:nodoc: #:notnew:
    # Watcher debugging facility
    if WATCHER_DEBUG
      # Open our dump file, and let Ruby environment close it when we exit.
      begin
        # mode 'a' appends to file, and 'w' truncates file if not empty.
        @debug_out = File.open(WATCHER_DEBUG_OUTPUT_FILENAME,'a')
      rescue Exception
        # if we couldn't open it, just send debugging data to STDERR,
        # and insert a message indicating the failure.
        @debug_out = STDERR
        @debug_out << "could not open [#{WATCHER_DEBUG_OUTPUT_FILENAME}]. " \
           + $!.message + "\n"
      end
      @debug_out << "****************************************\n"
      @debug_out << Time.now.to_s + "* starting " + File.basename($0) + "\n"
      @debug_out.flush unless @debug_out == STDERR or @debug_out == STDOUT
    end

    # Watcher debugging facility
    if WATCHER_DEBUG and WATCHER_DEBUG_ATTRIBUTES
      @debug_out << "=== Explicitly requested attributes: \n"
      attributes.keys.each do |k|
        @debug_out << "\t:#{k} => #{attributes[k].inspect}\n"
      end
      @debug_out.flush unless @debug_out == STDERR or @debug_out == STDOUT
    end

    # Here we define the default values for a newly created Watcher object.
    # * If passed nil on :output, must specifically delete Hash key.
    # * Merge the input attributes Hash given to Watcher.create with a
    #   local inline Hash below.
    # * Any keys provided by the user simply cause the associated key
    #   values provided by the consumer code to overwrite the values
    #   provided in the literal Hash below.  Isn't Ruby fun?
    attributes.delete(:output_path) if attributes[:output_path] == nil
    attributes={
      :default_fail => {:failure => :error},
      :error_symbol => nil, :warn_symbol => nil,
      :merge_newlines => ' (LF) ', :output_path => $stderr,
      :time_formatter => lambda { Time.now.to_s },
      :verbosity => :always,
      :write => :append,
    }.merge(attributes)

    # Watcher debugging facility
    if WATCHER_DEBUG and WATCHER_DEBUG_ATTRIBUTES
      @debug_out << "=== Merged attributes: \n" << "\n"
      attributes.keys.each do |k|
        @debug_out << "\t:#{k} => #{attributes[k].inspect}\n"
      end
      @debug_out.flush unless @debug_out == STDERR or @debug_out == STDOUT
    end

    # initialize public attributes
    @errors = 0
    @warnings = 0

    # initialize private attributes
    @last_hier = nil               # no last events at start
    @event_relationship = :child    # first event will be a child of...nil

    # Array of Event instances for working with nested levels.
    @events = Array.new

    # Here the product of the merges Hashes is used to populate the
    # instantiated Watcher object attributes.
    # Nothing to see here, move on...  Unless you want to improve
    # Watcher...
    @default_fail = attributes[:default_fail]
    @error_symbol = attributes[:error_symbol]
    @warn_symbol = attributes[:warn_symbol]
    @merge_newlines = attributes[:merge_newlines]
    @output_path = attributes[:output_path]
    @time_formatter = attributes[:time_formatter]
    @verbosity = attributes[:verbosity]
    @write_mode = attributes[:write]

    # after the attribute merge, perform sanity checks
    unless @time_formatter.kind_of?(Proc)
      raise ArgumentError(":time_formatter must be a Proc instance")
    end

    # make sure verbosity makes sense
    unless @@verbosity_levels.include?(@verbosity)
      raise ArgumentError.new(":verbosity must be one of #{@@verbosity_levels.inspect}")
    end

    # verify file output mode
    @write_mode = case @write_mode
    when :append
      'a'
    when :overwrite
      'w'
    else
      msg = "Watcher.initialize: :write must be one of either :overwrite" \
        + " or :append, not #{@write_mode.inspect}."
      raise ArgumentError.new(msg)
    end

    # Watcher debugging facility
    if WATCHER_DEBUG and WATCHER_DEBUG_ATTRIBUTES
      @debug_out << "=== Instance attributes: \n" << "\n"
      @debug_out << "    @default_fail\t\t=#{@default_fail.inspect}" << "\n"
      @debug_out << "    @error_symbol\t\t=\"#{@error_symbol}\"" << "\n"
      @debug_out << "    @warn_symbol\t\t=\"#{@warn_symbol}\"" << "\n"
      @debug_out << "    @merge_newlines\t\t=#{@merge_newlines}" << "\n"
      @debug_out << "    @output_path\t\t\t=#{@output_path}" << "\n"
      @debug_out << "    @time_formatter\t\t=#{@time_formatter}" << "\n"
      @debug_out << "    @verbosity\t\t\t=:#{@verbosity}" << "\n"
      @debug_out.flush unless @debug_out == STDERR or @debug_out == STDOUT
    end

    # Open the log file if not STDERR nor STDOUR
    if @output_path != STDERR and @output_path != STDOUT
      @output_path = File.expand_path(@output_path)
      @output = File.open(@output_path, @write_mode)
      unless @output # Redirect to STDOUT if open failed.
        @output = STDOUT
        @debug_out << "could not open [#{output_path}]. " + e.message \
          + "\n" if WATCHER_DEBUG
      end
    else
      @output = @output_path
    end
  end # initialize

  # Get the time String, but protect against if plug-in Proc causes an
  # Exception.
  def get_protected_log_time_string
    @time = begin
      @time_formatter.call
    rescue
      Time.now.to_s + " (WARNING! :time_formatter Proc raised #{$!.class} exception) "
    end
  end

  # When either #debug or #verbose is invoked, it ends up passing the
  # batton to the private #monitor method.
  # * #monitor first sets up some local variables, including setting up a
  #   variable to store the effective default_fail for reasons decribed below,
  #   then optionally makes a log entry concerning the title you desire to
  #   execute.  This log entry only takes place if the verbosity level of the
  #   title is equal to or exceeds the Watcher object's stored verbosity
  #   minimum level, @verbosity.
  # * After preparations are complete, Watcher checks whether you sent the
  #   #debug or #verbose method a block to execute. If you did not send a block,
  #   Watcher simply returns control to your code at the point immediately
  #   following where you invoked Watcher.
  # * If you did pass a block to execute, Watcher sets up a
  #   <tt>begin...rescue...end</tt> Exception handling block and invokes your
  #   block inside that protective environment.
  # * If code invoked by that block triggers an Exception, Watcher passes
  #   control to the #protect method, which orchestrates a recovery path based
  #   on the consumer provided default_fail Array.  If the #debug or #verbose
  #   methods were not given a specific set of actions to perform if an
  #   Exception occurs, then the Watcher object uses its object instance
  #   attribute @event_fail to provide the list of actions to complete.  For
  #   information how this works, see the documentation for the #protect
  #   method.
  def monitor(title, run_level, block_was_given, event_fail) #:doc:
    # Why have @events, an Array of events?
    # * When new title is started, if its title level meets or exceeds the
    #   Watcher verbosity level, the @events Array is cleared and the event
    #   is sent to the log.  The @events Array must be cleared because
    #   preceeding indentation will not otherwise line up.
    # * When new title is started, if its title level is lower than the Watcher
    #   verbosity level, its event Hash is appended to the @events Array for
    #   later log replay if exception is thrown.
    # * When title is successfully completed, its matching event Hash is
    #   located (from the right) of the @events Hash, and it and all following
    #   events are removed from the @events Array.
    # * When title is unsuccessfully completed, a event replay is performed and
    #   all events in the @events Hash are sent to the logs regardless of
    #   their event level.  This way an understandable stack-frame replay is
    #   possible to determine the actual cause of the exception.
    result = nil

    if WATCHER_DEBUG and WATCHER_DEBUG_FAIL_ACTIONS
      @output.puts "WATCHER MONITOR -- FAIL_ACTIONS for [#{title}]"
      event_fail.each { |k,v| @output << " #{k.inspect} == #{v.inspect}\n" }
    end

    # Validate input; abort if input parameters are not clean.
    #   (@time, @last_hier, @title, @fail_actions, @relationship)
    event = Event.new(get_protected_log_time_string, @last_hier, title, \
      event_fail, @event_relationship)

    # Validate input; abort if input parameters are not clean.
    unless @@verbosity_levels.has_key? run_level
      # Defensive programming
      msg = "Watcher.monitor: The second argument (run_level) must be one" \
        + ' of '  + @@verbosity_levels.inspect + ".  Your argument was" \
        + run_level.inspect + ". Aborting [#{title}]"
      raise ArgumentError.new(msg)
    end

    # Either append this event to @events Array, or send it to the log
    if @@verbosity_levels[run_level] < @@verbosity_levels[@verbosity]
      # This event is lower than our minimum verbosity, so store it in our
      # Array for replay if needed later.
      @events << event
      @debug_out << "* HIDDEN: #{event}\n" if WATCHER_DEBUG and WATCHER_DEBUG_VERBOSITY
    else
      # forget previous replays since this gets printed
      @debug_out << "* VISIBLE:#{event.to_s} (*) clearing previous #{@events.size} events from array\n" if WATCHER_DEBUG and WATCHER_DEBUG_VERBOSITY
      @events = Array.new

      # NOTE:  event.to_s retuns time-stamp then its event hier
      @output << event.to_s + "\n"
      @output.flush # Do this always, not just 'if WATCHER_DEBUG'
    end

    # If event has a block, protect and execute the block
    if block_was_given # block_given? from #debug or #verbose
      if WATCHER_DEBUG and WATCHER_DEBUG_OUTPUT and false
        @output << " +monitor_block(#{event.title})"
      end
      result = monitor_block(event) { yield }
    end # block given

    # Once this Event is complete, make the next event a sibling of this event
    @event_relationship = :sibling
    @last_hier = event.hier.dup

    if WATCHER_DEBUG and WATCHER_DEBUG_VERBOSITY
      @debug_out << "(L) @last_hier = " + @last_hier + "\n"
      @debug_out.flush
    end

    result
  end

  def monitor_block (event)
    # During execution of the parameterized block, the following events must
    # be children events of this event.  After the block completes, following
    # events are sibling events of this event.
    @event_relationship = :child
    @last_hier = event.hier.dup
    result = nil

    # Event knows its own max tries value
    tries_remaining = event.tries

    begin
      tries_remaining -= 1
      result = yield
    rescue # from exception thrown during original yield
      # Start by sending all queued (hidden) events to the log. (They were
      # only queued up so we could log them in event of a failure.)
      # NOTE: @events could be empty...that's okay.
      @events.each do |e|
        @output << e.to_s
        @output << " (flushed)" if WATCHER_DEBUG and WATCHER_DEBUG_OUTPUT
        @output << "\n"
      end
      # After we output all hidden events, we erase the @events Array,
      # so we don't output them on the next retry failure.
      @events = Array.new

      @output << get_protected_log_time_string + ': ' \
        + event.hier + ' ***'

      # Place error or warning flag in the log
      if tries_remaining == 0 and event.failure == :error
        if @error_symbol != nil and @error_symbol != ''
          @output << ' ' + @error_symbol
        end
      else
        if @warn_symbol != nil and @warn_symbol != ''
          @output << ' ' + @warn_symbol
        end
      end

      # Append to log result of merging newlines from exception message
      if @merge_newlines != nil and @merge_newlines != ''
        @debug_out.puts "[#{$!.message}]" if WATCHER_DEBUG and WATCHER_DEBUG_OUTPUT
        message = $!.message.split(/\n/).join @merge_newlines
      end
      @output << ' ' + message + "\n"
      @output.flush

      if tries_remaining > 0
        begin
          # Call the user-supplied recovery Proc with the original exception
          event.proc.call($!)
        rescue # from exception during user's recovery proc
          # If user-supplied Proc caused an Exception, then bail
          @errors += 1
          raise $!
        end

        @output << get_protected_log_time_string + ': ' \
          + event.hier + ' ### '
        @output << case tries_remaining
        when 1
          "(1 try left)\n"
        else
          '(' + tries_remaining.to_s + " tries left)\n"
        end
        @output.flush

        retry
      else # no more retries remaining
        if not $!.kind_of? Exception
          raise "$! no longer an exception [#{$!.inspect}]"
        end
        if event.failure == :error
          @errors += 1
          raise $!
        else
          @warnings += 1
          @output.flush
        end
      end # perform a retry attempt
    ensure
      # Once this Event is complete, make the next event a sibling of this event
      @event_relationship = :sibling
      @last_hier = event.hier.dup
    end # rescue from top tier exception
    result
  end

  # Set to true when Watcher should execute itself in debugging mode.
  WATCHER_DEBUG = false

  # Set to true when debugging Watcher failure actions.
  WATCHER_DEBUG_FAIL_ACTIONS = false

  # Set to true when debugging Watcher verbosity levels.
  WATCHER_DEBUG_VERBOSITY = false

  # Name of file that Watcher creates for its debugging output.
  WATCHER_DEBUG_OUTPUT_FILENAME = 'watcher-debug.log'

  # Set to true when debugging Watcher instance attribute settings.
  WATCHER_DEBUG_ATTRIBUTES = false

  # Set to true when debugging Watcher's log strings.
  WATCHER_DEBUG_OUTPUT = false
end

# Watcher.require_all_libs_relative_to(__FILE__)
