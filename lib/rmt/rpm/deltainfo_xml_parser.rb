class RMT::Rpm::DeltainfoXmlParser < RepomdParser::DeltainfoXmlParser
  include UtilsMixin

  def end_element(name)
    return unless delta? name

    unless delta_src_package_with_mirror_src?
      build_reference_for_package_with_src(@delta, :drpm)
      return
    end

    super.end_element(name)
  end

  private

  def delta?(name)
    name == 'delta'
  end

  def delta_src_package_with_mirror_src?
    (@package[:arch] == 'src' && !@mirror_src)
  end
end
