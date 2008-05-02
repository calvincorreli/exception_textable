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

class ExceptionTexter
  @@recipients = []
  cattr_accessor :recipients
  
  @@text_prefix = "[ERROR] "
  cattr_accessor :text_prefix

  @@clickatell_options = {}
  cattr_accessor :clickatell_options

  @@email_options = {}
  cattr_accessor :email_options

  # Used internally to throttle text messages
  
  @@exception_sms_at = []
  cattr_accessor :exception_sms_at
  
  @@exception_sms_by = {}
  cattr_accessor :exception_sms_by
  
  class << self
  
    def deliver(exception, controller, data = nil)
      text = get_text(exception, controller, data)
      results = []
      for recipient in recipients 
        results << send(*(recipient + [text]))
      end
      results
    end
    
    def suppress?(exception, controller)
      return true if suppress_exception?(exception) || suppress_by_time? || suppress_by_action?(exception, controller)
      record_delivery(exception, controller)
      false
    end

    # The gateways
    
    def clickatell(recipient, text)
      params = clickatell_options.stringify_keys
      params["text"] = text.to_s[0...153]
      params["to"]   = recipient      
      url = "/http/sendmsg?" + params.map {|key,value| "#{key}=#{CGI::escape(value.to_s)}" } * "&"
      result = do_https("api.clickatell.com", url).chomp      
      if success = result =~ /^ID: /
        RAILS_DEFAULT_LOGGER.info "Sent exception notification SMS through Clickatell: #{result}"
      else
        RAILS_DEFAULT_LOGGER.error "Error sending exception notification SMS through Clickatell: #{result}"
      end
      success
    end    

    def email(recipient, text)
      m = TMail::Mail.new
      m.set_content_type 'text', 'plain'

      m.to      = recipient + email_options[:suffix].to_s
      m.from    = email_options[:from]
      m.subject = email_options[:subject]
      m.body    = text.to_s[0...153]

      ActionMailer::Base.deliver(m)
    end
    
    def test(recipient, text)
      RAILS_DEFAULT_LOGGER.info "ExceptionTexter.test gateway: Sending #{text.inspect} to #{recipient}"
    end
    
    protected
      def get_text(exception, controller, data = nil)
        text = "#{text_prefix}#{controller.controller_name}##{controller.action_name} (#{exception.class}) #{exception.message.inspect}"
        text << " - #{PP.pp(data)}" if data
        text
      end
    
      def do_https(host, url)
        http = Net::HTTP.new(host, 443)
        http.use_ssl = true
        request = Net::HTTP::Get.new(url)
        result = nil
        http.start() { |f| result = http.request(request).body }
        result
      end

      def suppress_exception?(exception)
        %w(ActiveRecord::RecordNotFound ActionController::UnknownController ActionController::UnknownAction ActionController::RoutingError).include?(exception.class.to_s)
      end
    
      def suppress_by_time?
        @@exception_sms_at.reject! {|t| t < 1.hour.ago }
        @@exception_sms_at.size >= 5
      end
    
      def suppress_by_action?(exception, controller)
        action = "#{controller.controller_name}##{controller.action_name}"
        @@exception_sms_by[action] ||= []
        @@exception_sms_by[action].reject! {|t| t < 6.hours.ago }
        @@exception_sms_by[action].size >= 2
      end
    
      def record_delivery(exception, controller)
        @@exception_sms_at << Time.now
        @@exception_sms_by["#{controller.controller_name}##{controller.action_name}"] << Time.now
      end
  end
end