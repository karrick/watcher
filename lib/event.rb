#!/usr/bin/env ruby

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
  ##### Publically read-write attributes

  ##### Publically read-only attributes
  attr_reader :failure      # what to do if all tries fail (:warn | :error)
  attr_reader :hier         # shows nested levels
  attr_reader :proc         # Proc to call before a retry
  attr_reader :tries        # number of tries remaining
  attr_reader :title        # event title

  # Get an Event which is the child of this event
  def child
    self.dup.child!
  end

  # Make this event into its child
  def child!
    if @hier.count('.') % 2 == 0 # if even number of periods
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

  ########## Return String ready for log
  def to_s
    @time + ': ' + @hier + ' ### ' + @title
  end

  ########################################
  private
  ########################################

  # Create a new Event instance with the specified task title, and an optional
  # prefix for parent event id (used for log replay)
  def initialize(time, hier, title, fail_actions, relationship)
    @hier = hier
    @time = time
    @title = title

    # validate title
    unless title.respond_to? :to_s
      # Defensive programming against Watcher's caller:
      msg = "Event.initialize: The first argument (title) must respond to" \
        + " the :to_s method. Your argument class is #{title.class}." \
        + " Aborting task."
      raise ArgumentError.new(msg)
    end

    # validate time
    unless time.respond_to? :to_s
      # Defensive programming against Watcher's caller:
      msg = "Event.initialize: The second argument (time) must respond to" \
        + " the :to_s method. Your argument class is #{time.class}." \
        + " Aborting [#{title}]."
      raise ArgumentError.new(msg)
    end

    # validate fail actions
    if fail_actions.kind_of? Hash
      # validate fail_actions (throws ArgumentError if bad; let caller catch)
      @proc = fail_actions[:proc]
      @tries = fail_actions[:tries]
      @failure = fail_actions[:failure]
      validate_fail_actions
    else
      # Defensive programming against Watcher's caller:
      msg = "Event.initialize: The fourth argument (fail_actions) must be" \
        + " a Hash, not a #{fail_actions.class}. Aborting [#{title}]."
      raise ArgumentError.new(msg)
    end

    # validate hier argument
    if hier == nil
      # If no hier event, then this Event has no parent or siblings.
      @hier = '0'
    elsif not hier.kind_of? String
      # Defensive programming against Watcher.monitor
      msg = "Event.initialize: sixth argument (hier) must be either nil," \
        + " or of non-zero length String, not a #{hier.class}. Aborting [#{title}]."
      raise ArgumentError.new(msg)
    elsif hier == ''
      # Defensive programming against Watcher.monitor
      msg = "Event.initialize: sixth argument (hier) must be either nil," \
        + " or of non-zero length String. Aborting [#{title}]."
      raise ArgumentError.new(msg)
    else # this event is related to hier
      case relationship
      when :child
        @hier = hier
        child!
      when :sibling
        @hier = hier
        sibling!
      else
        msg = "Event.initialize: fifth argument (relationship) must be one" \
          + " of either :child or :sibling"
        raise ArgumentError.new(msg)
      end
    end
  end

# Deprecated, but worked fine at the time it was taken out.
# # Take this Event hier to back up one hier from the call-stack
# def dec
#   # knock off the last segment
#   @hier.sub!(/\.?[^.]+$/, '')
#   # call sibling to increment parent hier
#   sibling!
# end

  # Validate fail_actions parameter (throws ArgumentError if bad)
  # * Must include either :warn or :error, but not both in Hash.
  # * If :tries is specified, it must be a Fixnum, and then :proc must also
  #   be specified, and a valid Proc instance.
  # * If :tries is not specified, then :proc may not be specified.
  def validate_fail_actions
    # Either :warn or :error, not both, and not neither.
    if @failure != :warn and @failure != :error
      msg = "Event.validate_fail_actions: Must specify either :warn or :error"
      raise ArgumentError.new(msg)
    end

    # If :tries is set, then it must be a Fixnum
    if @tries != nil
      if @tries.class != Fixnum or @tries < 2
        raise ArgumentError.new(':tries must be at least 2 in order to specify a Proc')
      else # must have a valid Proc
        if @proc.class != Proc
          raise ArgumentError.new('must specify a Proc instance when :tries is set')
        end
      end
    else # tries is nil
      # Ensure :proc not set
      if @proc != nil
        raise ArgumentError.new(':tries must be at least 2 in order to specify a Proc')
      end
      @tries = 1 # just one try since :proc was nil
    end
  end
end
