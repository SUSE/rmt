class RMT::Rpm::PrimaryXmlParser < RepomdParser::PrimaryXmlParser
  include UtilsMixin
  def end_element(name)
    return unless package? name

    unless primary_src_package_with_mirror_src?
      build_reference_for_package_with_src(@package, :rpm)
      return
    end

    super.end_element(name)
  end

  private

  def package?(name)
    name == 'package'
  end

  def primary_src_package_with_mirror_src?
    @package[:arch] == 'src' && !@mirror_src
  end
end
