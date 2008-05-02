# Copyright (c) 2006 Lars Pind
#
# Loosely based on Exception Notifier by Jamis Buck
# http://dev.rubyonrails.org/svn/rails/plugins/exception_notification/README
#
# Permission is hereby granted, free of charge, to any person obtaining
# a copy of this software and associated documentation files (the
# "Software"), to deal in the Software without restriction, including
# without limitation the rights to use, copy, modify, merge, publish,
# distribute, sublicense, and/or sell copies of the Software, and to
# permit persons to whom the Software is furnished to do so, subject to
# the following conditions:
#
# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
# LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
# OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
# WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
module ExceptionTextable
  def self.included(target)
    target.class_eval do
      target.extend(ClassMethods)
      alias_method :rescue_action_in_public_without_sms, :rescue_action_in_public 
      alias_method :rescue_action_in_public, :rescue_action_in_public_with_sms
    end
  end
  
  module ClassMethods
    def exception_sms_data(deliverer=self)
      if deliverer == self
        read_inheritable_attribute(:exception_sms_data)
      else
        write_inheritable_attribute(:exception_sms_data, deliverer)
      end
    end
  end
  
  def exception_sms_data
    deliverer = self.class.exception_sms_data
    data = case deliverer
      when nil then nil
      when Symbol then send(deliverer)
      when Proc then deliverer.call(self)
    end
  end
  
  def suppress_exception_sms?(exception)
    ExceptionTexter.suppress?(exception, self)
  end

  def deliver_exception_sms(exception)
    if suppress_exception_sms?(exception)
      logger.info "Exception SMSes Suppressed"
    else
      ExceptionTexter.deliver(exception, self, exception_sms_data) unless suppress_exception_sms?(exception)
      logger.info "Exception SMSes Sent"
    end
  end

  def rescue_action_in_public_with_sms(exception)
    rescue_action_in_public_without_sms(exception)
    deliver_exception_sms(exception)
  end
end