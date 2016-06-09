require 'active_support/concern'

module SpreeTaxCloud
  module AddressValidator
     extend ActiveSupport::Concern
  
    private
    def confirm_with_tax_cloud
      
      Rails.logger.debug "TaxCloud::AddressValidator - validating [#{self.inspect}]"
      
      begin
        
      if response = tax_cloud_transaction.lookup
        Rails.logger.debug "TaxCloud::AddressValidator : response #{response.inspect}"
        Rails.logger.info "TaxCloud::AddressValidator : address '#{self}' confirmed"
        return true
      end
        
      rescue Exception => @error
        
        Rails.logger.debug("#{@error.inspect}")
        Rails.logger.info "TaxCloud::AddressValidator : address '#{self}' invalid"
        return errors.add(:zipcode, :invalid) if invalid_zipcode?
        return errors.add(:base, :invalid) if invalid_parameters?
        raise @error
        
      end
      
    end
    
    def confirm_with_usps
      Rails.logger.debug("TaxCloud::AddressValidator - confirmed_by_usps [#{self}]")
    end
    
    def tax_cloud_transaction
      transaction = TaxCloud::Transaction.new(
        origin: origin,
        destination: destination,
        cart_items: dummy_cart
      )
      transaction.customer_id = Digest::SHA1.hexdigest(transaction.inspect)
      Rails.logger.debug "TaxCloud::AddressValidator #tax_cloud_transaction: #{transaction.inspect}"
      return transaction
    end
    
    def origin
      TaxCloud::Address.new(city: 'New York', state: 'NY', zip5: '10004')
    end
    
    def destination
      Spree::TaxCloud.address_from_spree_address(self)
    end
    
    def dummy_cart
      cart_items = []
      cart_items << TaxCloud::CartItem.new(index: 0, item_id: 'SKU-TEST', tic: TaxCloud::TaxCodes::GENERAL, quantity: 1, price: 1)
    end
    
    def invalid_parameters?
      @error.resolution == 'Check the request parameters.'
    end
    
    def invalid_zipcode?
        @error.problem.include? 'is not valid for this state'
    end
    
    def zipcode_or_state_changed?
     (["zipcode","state_id"] & changed_attributes.keys).present?
    end
    
  end
end