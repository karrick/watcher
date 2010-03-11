# Watcher Tests
#
# Summary::   Watcher provides advanced integrated exception handling and
#             logging functionality to your Ruby programs.
# Author::    Karrick McDermott (karrick@karrick.org)
# Date::      2008-07-04
# Copyright:: Copyright (c) 2008 by Karrick McDermott.  All rights reserved.
# License::   Simplified BSD License.

######################################################################

require "test_helpers.rb"
require "event"

class TestEvent < Test::Unit::TestCase
  def setup
    @title = 'TITLE'
    @time = Time.now.utc
    @fail_actions = {:failure => :error}
    @relationship = :child
    @base = nil

    # Create a root event node
    #   (time, hier, title, fail_actions, relationship)
    @root = Event.new(@time, nil, @title, @fail_actions, :child)
  end

  def test_child_of_child
    first_child = @root.child
    assert_kind_of(Event, first_child)
    assert_equal('0.a', first_child.hier)

    second_child = first_child.child
    assert_equal('0.a.0', second_child.hier)
  end

  def test_sibling_of_sibling
    first_sibling = @root.sibling
    assert_kind_of(Event, first_sibling)
    assert_equal('1', first_sibling.hier)

    second_sibling = first_sibling.sibling
    assert_kind_of(Event, second_sibling)
    assert_equal('2', second_sibling.hier)
  end

  def test_child_of_sibling
    sibling = @root.sibling
    assert_kind_of(Event, sibling)
    assert_equal('1', sibling.hier)

    child = sibling.child
    assert_kind_of(Event, child)
    assert_equal('1.a', child.hier)
  end

  def test_sibling_of_child
    child = @root.child
    assert_kind_of(Event, child)
    assert_equal('0.a', child.hier)

    sibling = child.sibling
    assert_kind_of(Event, sibling)
    assert_equal('0.b', sibling.hier)
  end

# def test_initialize_fail_actions
#   assert_raise(:ArgumentError) { Event.new(@time, nil, @title, {}, :child)
#
# end
end
