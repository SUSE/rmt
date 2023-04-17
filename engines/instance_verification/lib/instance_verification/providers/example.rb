class InstanceVerification::Providers::Example < InstanceVerification::ProviderBase
  # Unique identifier for SLES sent by client instance
  SLES_PRODUCT_IDENTIFIER = '1234_SUSE_SLES'.freeze
  # Unique identifier for SLES For SAP sent by client instance
  SLES4SAP_PRODUCT_IDENTIFIER = '6789_SUSE_SAP'.freeze

  def instance_valid?
    # Extract the instance identifier from the instance data sent by the client
    instance_product_id = validate_instance_data(@instance_data)
    return true if (@product_hash[:identifier].casecmp('sles').zero? && instance_product_id == SLES_PRODUCT_IDENTIFIER)
    return true if (@product_hash[:identifier].casecmp('sles_sap').zero? && instance_product_id == SLES4SAP_PRODUCT_IDENTIFIER)

    raise InstanceVerification::Exception, 'Product/instance type mismatch'
  end

  def validate_instance_data(_instance_data)
    # The instance data format is determined by the client implementation and needs to
    # be processed here accordingly. Ideally the data is signed in a way such that it can
    # be independently verified here to not have been tampered with in flight or injected
    # into the stream. The AWS implementation of the Instance Identity Document is one possible
    # implementation route. In this example it is assumed the instance data is json and
    # contains instance_product_id

    return '1234_SUSE_SLES' if @product_hash[:identifier].casecmp('sles').zero?

    return '6789_SUSE_SAP' if @product_hash[:identifier].casecmp('sles_sap').zero?
  end

  def parse_instance_data(_instance_data)
    { 'instance_data' => 'parsed_instance_data' }
  end

  def payg_billing_code?(billing_product, marketplace_code, identifier)
    return true if (identifier.casecmp('sles').zero? && billing_product == SLES_BILLING_PRODUCT)
    return true if (identifier.casecmp('sles_sap').zero? && SLES_SAP_CODES.include?(marketplace_code))
  end
end
