ENV["RAILS_ENV"] = "test"
require File.expand_path(File.dirname(__FILE__) + "/../../../../config/environment")
require 'test/unit'
require File.expand_path(File.dirname(__FILE__) + '/../init')

class ExceptionTextableTest < Test::Unit::TestCase

  def setup
    @exception  = RuntimeError.new("test")
    @controller = Struct.new("Controller", :controller_name, :action_name).new("Controller", "action")
  end
  
  def test_test_gateway
    ExceptionTexter.recipients = [[:test, "foo"]]
    ExceptionTexter.deliver(@exception, @controller)    
  end

  def test_email_gateway
    ActionMailer::Base.deliveries.clear    
    ExceptionTexter.recipients = [[:email, "foo@example.test"]]
    ExceptionTexter.deliver(@exception, @controller)
    assert_equal 1, ActionMailer::Base.deliveries.size
    assert_equal ["foo@example.test"], ActionMailer::Base.deliveries.last.to
  end
end
