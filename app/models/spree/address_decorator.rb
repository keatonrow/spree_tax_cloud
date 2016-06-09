module Spree
  Address.class_eval do
    include SpreeTaxCloud::AddressValidator
    
    alias_method :original_postal_code_validate, :postal_code_validate
    
    def postal_code_validate
      original_postal_code_validate
      confirm_with_tax_cloud if errors.empty? && zipcode_or_state_changed?
    end
    
  end
end