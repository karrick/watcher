# Event
#
# Summary::   Event instance handles exception recovery, proper hierarchical
#             format String for the log based on its level in the call-stack.
# Author::    Karrick McDermott (karrick@karrick.org)
# Date::      2008-07-22
# Copyright:: Copyright (c) 2008 by Karrick McDermott.  All rights reserved.
# License::   Internet Systems Consortium (ISC) License (ISCL)

######################################################################

######################################################################
# An Event instance tracks the title of the task, and the required indentation
# to display the task in the log.  This is required to store an Array of
# events that took place--but below the verbosity threshhold--to replay them
# into the log at the appropriate indention level should an exception be
# thrown.
class Event
  VALID_FAILURES = [:error, :warn]

  attr_reader :failure      # what to do if all tries fail (:warn | :error)
  attr_reader :hier         # shows nested levels
  attr_reader :proc         # Proc to call before a retry
  attr_reader :tries        # number of tries remaining
  attr_reader :title        # event title

  # Create a new Event instance with the specified task title, and an optional
  # prefix for parent event id (used for log replay)
  def initialize(time, hier, title, fail_actions, relationship)
    @hier = hier
    @time = time
    @title = title
    @fail_actions = fail_actions
    @relationship = relationship

    validate_title
    validate_time
    validate_hier_and_relationship
    validate_fail_actions
  end

  # Get an Event which is the child of this event
  def child
    self.dup.child!
  end

  # Transform this event into its child
  def child!
    if child_count_is_even?
      @hier << '.a'
    else
      @hier << '.0'
    end
    self
  end

  # Get copy of Event hier to the next task at the same level of the call-stack
  def sibling
    self.dup.sibling!
  end

  # Take this Event hier to the next task at the same level of the call-stack
  def sibling!
    # Now change the last hier to its successor
    @hier.sub!(/[^.]+$/) { $&.succ }
    self
  end

  def to_s
    @time + ': ' + @hier + ' ### ' + @title
  end

  ########################################
  private
  ########################################

  def child_count_is_even?
    @hier.count('.') % 2 == 0 ? true : false
  end

  def validate_title
    unless @title.respond_to? :to_s
      # Defensive programming against Watcher's caller:
      msg = "Event.initialize: The first argument (title) must respond to" \
      + " the :to_s method. Your argument class is #{@title.class}." \
      + " Aborting task."
      raise ArgumentError.new(msg)
    end
  end

  def validate_time
    unless @time.respond_to? :to_s
      # Defensive programming against Watcher's caller:
      msg = "Event.initialize: The second argument (time) must respond to" \
      + " the :to_s method. Your argument class is #{@time.class}." \
      + " Aborting [#{title}]."
      raise ArgumentError.new(msg)
    end
  end

  def validate_hier_and_relationship
    if @hier == nil
      # If no hier event, then this Event has no parent or siblings.
      @hier = '0'
    elsif not @hier.kind_of? String
      # Defensive programming against Watcher.monitor
      msg = "Event.initialize: sixth argument (hier) must be either nil," \
      + " or of non-zero length String, not a #{hier.class}. Aborting [#{@title}]."
      raise ArgumentError.new(msg)
    elsif @hier == ''
      # Defensive programming against Watcher.monitor
      msg = "Event.initialize: sixth argument (hier) must be either nil," \
      + " or of non-zero length String. Aborting [#{@title}]."
      raise ArgumentError.new(msg)
    else # this event is related to hier
      case @relationship
      when :child
        child!
      when :sibling
        sibling!
      else
        msg = "Event.initialize: fifth argument (relationship) must be one" \
        + " of either :child or :sibling"
        raise ArgumentError.new(msg)
      end
    end
  end

  def validate_fail_actions
    # validate fail actions
    if @fail_actions.kind_of? Hash
      # validate fail_actions (throws ArgumentError if bad; let caller catch)
      @proc = @fail_actions[:proc]
      @tries = @fail_actions[:tries]
      @failure = @fail_actions[:failure]
      validate_failure
      validate_proc_and_tries
    else
      # Defensive programming against Watcher's caller:
      msg = "Event.initialize: The fourth argument (fail_actions) must be" \
      + " a Hash, not a #{@fail_actions.class}. Aborting [#{@title}]."
      raise ArgumentError.new(msg)
    end
  end

  def validate_failure
    unless VALID_FAILURES.include?(@failure)
      raise ArgumentError.new("Must specify item from list #{VALID_FAILURES.inspect}")
    end
  end

  def validate_proc_and_tries
    @tries = @tries.to_i

    case @proc
    when nil
      ensure_tries_not_greater_than_one
    when Proc
      ensure_tries_is_valid_integer
    else
      raise ArgumentError.new(":proc must be either a Proc object, or nil")
    end
  end

  def ensure_tries_not_greater_than_one
    if @tries > 1
      raise ArgumentError.new(":tries cannot be greater than one if Proc is not given")
    end
  end

  def ensure_tries_is_valid_integer
    if @tries < 0
      raise ArgumentError.new(":tries must be greater than -1 if Proc is given")
    end
  end

  private :validate_failure, :validate_proc_and_tries
  private :ensure_tries_not_greater_than_one, :ensure_tries_is_valid_integer
end
