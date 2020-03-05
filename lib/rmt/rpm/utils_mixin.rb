module UtilsMixin
  attr_reader :referenced_files
  def initialize(filename, mirror_src = false)
    super(filename)
    @mirror_src = mirror_src
  end

  def build_reference_for_package_with_src(receiver, type)
    @referenced_files << RepomdParser::Reference.new(
      location: receiver[:location],
       checksum_type: receiver[:checksum_type],
       checksum: receiver[:checksum],
       type: type,
       size: receiver[:size].to_i || nil
     )
  end
end
