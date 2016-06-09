module SpreeTaxCloud
  class Backfiller
  
    def errors
      @errors ||= {:tax_match => [], :already_authorized => [], :already_captured => [], :others => []}
    end
    
    def success
      @success ||= []
    end
    
    def authorized_with_capture(order, options={})
      if validate(order, options)
        options = {date_authorized: order.completed_at, date_captured: order.completed_at}.merge(options)
        process(order,:authorized_with_capture, options)
        if errors[:already_authorized].delete(order.number)
          process(order,:captured, options)
        end
      end
    end
    
    def authorized(order, options={})
      if validate(order, options)
        options = {date_authorized: order.completed_at}.merge(options)
        process(order,:authorized, options)
      end
    end
    
    def captured(order, options={})
      if validate(order, options)
        options = {date_captured: order.completed_at}.merge(options)
        process(order,:captured, options)
      end
    end
    
    def print_results
      Rails.logger.info("Transaction backfilled: #{success.count}")
      errors.each do |type, list|
        next if list.count == 0
        Rails.logger.info("Transaction #{type.to_s} (#{list.count}): #{list.inspect}")
        end
      end
      
      private
      
      def process(order, method, options={})
        begin
          transaction = Spree::TaxCloud.transaction_from_order(order)
          transaction.send(method.to_sym, options)
          success << order.number
        rescue Exception => e
            handle_error(order, e)
        end
      end
      
      def tax_match(order, options={})
        options = {:tax_match => true}.merge(options)
        return true unless options[:tax_match]
        begin
          # verify tax
          transaction = Spree::TaxCloud.transaction_from_order(order)
          tax_amount = transaction.lookup.tax_amount.to_d.round(2)
          
          if order.tax_total != tax_amount
            Rails.logger.debug("Tax amount doesnt match for Order ##{order.number} (Spree: #{order.tax_total} vs TaxCloud: #{tax_amount})")
            errors[:tax_match] = {order.number => "(Spree: #{order.tax_total} vs TaxCloud: #{tax_amount})"}
            return false
          else
            Rails.logger.debug("tax amount verified for Order ##{order.number}")
            return true
          end
          
        rescue Exception => e
            handle_error(order, e)
        end
      end
      
      def validate(order, options={})
         unless order.completed_at
           errors[:incomplete] = {order.number => "Order is not completed"}
           return false
         end
         unless tax_match(order, options)
           return false
         end
         return true
      end
      
      def handle_error(order, e)
        problem = e.try(:problem)
        if problem && problem.include?('This transaction has already been marked as authorized')
            errors[:already_authorized] << order.number
        elsif problem && problem.include?('This transaction has already been captured')
            errors[:already_captured] << order.number
        else
            errors[:others] << {order.number => e}
        end
      end
    end
end