require "test_helpers.rb"
require "watcher"

class TestWatcher < Test::Unit::TestCase
  MAX_ATTEMPTS = 3

  def setup
    params = {:warn_symbol=>'WARNING', :error_symbol => 'ERROR'}
    params = params.merge(:verbosity => :verbose)
    params = params.merge(:default_fail => {:failure => :error})
    @w = Watcher.create(params)
  end

  def test_exception_causes_warning
    @w.verbose("Test -- exception causes warning") do
      # Ensure that when pass :warn, Watcher will not re-raise exception,
      # provided the :proc doesn't throw an exception as well
      assert_nothing_thrown do
        @w.debug("causing an exception, but catch with :warn", :failure => :warn) do
          raise RuntimeError.new("exception")
        end
      end
    end
  end

  def test_exception_reraised
    @w.verbose("Test -- exception re-raised") do
      # Ensure that when no :failure passed, Watcher will re-raise exception
      assert_raise(RuntimeError) do
        @w.debug("causing an exception, no catch") do
          raise RuntimeError.new("exception")
        end
      end

      # Ensure that when pass :error, Watcher will re-raise exception,
      assert_raise(RuntimeError) do
        @w.debug("causing an exception, no catch", :failure => :error) do
          raise RuntimeError.new("exception")
        end
      end
    end
  end

  def test_retries_then_reraise
    @w.verbose("Test -- retries resulting in re-raising exception") do
      # Watcher will execute specified number of tries, then re-raise.
      # The Proc simply closes over out retry_count variable, incrementing it.
      attempt_count = 0   # Count how many tries actually occured
      assert_raise(RuntimeError) do
        @w.debug("causing exception with #{MAX_ATTEMPTS} tries then error", {:tries => MAX_ATTEMPTS, :proc => lambda { |e| attempt_count += 1 }, :failure => :error}) do
            raise RuntimeError.new("exception")
        end
      end
      # NOTE: off-by-one because we run Proc in-between attempts
      assert_equal(MAX_ATTEMPTS-1, attempt_count)
    end
  end

  def test_retries_then_warn
    @w.verbose("Test -- retries resulting in log warning") do
      # Watcher will execute specified number of tries, then warn.
      # The Proc simply closes over out retry_count variable, incrementing it.
      attempt_count = 0   # Count how many tries actually occured
      assert_nothing_thrown do
        @w.debug("causing exception with #{MAX_ATTEMPTS} tries then warning", {:tries => MAX_ATTEMPTS, :proc => lambda { |e| attempt_count += 1 }, :failure => :warn}) do
            raise RuntimeError.new("exception")
        end
      end
      # NOTE: off-by-one because we run Proc in-between attempts
      assert_equal(MAX_ATTEMPTS-1, attempt_count)
    end
  end

  def test_embedded_levels
    @w.verbose("Test -- embedded levels") do
      assert_nothing_thrown do
        @w.debug("outside level, re-raise if error", :failure => :error) do
          @w.debug("inside level, warn if error", :failure => :warn) do
            raise RuntimeError.new("exception")
          end
        end
      end
    end
  end

  def test_send_email_without_output_file
    # Watcher with output sent to STDOUT, and give
    # signal to send email.
    # Result should append a note to the log.
    # (It should probably throw an exception, because invocation is wrong.)

    # Let's get an entry on the log, but don't wrap around a block
    @w.always("about to test sending email without output file")
    assert_raise(ArgumentError) do
      @w.send_email("root@localhost", "FAIL: Watcher should not have sent this")
    end
  end
end
