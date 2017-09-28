class V3::UpgradePathItemSerializer < ActiveModel::Serializer

  def base
    object.base?
  end

  def shortname
    object.shortname ? object.shortname : ''
  end

  def available
    object.mirror?
  end

  attributes :friendly_name, :shortname, :identifier, :version, :arch, :release_type, :base, :product_type, :free, :release_stage, :available

end
