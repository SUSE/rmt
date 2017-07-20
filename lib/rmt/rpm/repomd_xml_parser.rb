class RMT::Rpm::RepomdXmlParser < RMT::Rpm::BaseParser

  def parse
    xml = Nokogiri::XML(File.open(@filename))

    xml.xpath('/xmlns:repomd/xmlns:data').each do |data_node|
      type = data_node.attr('type').to_sym

      hash = {}
      data_node.xpath('./*').each do |node|
        hash[node.name.to_sym] = { value: node.text.to_s }

        node.attributes.each do |name, attr|
          hash[node.name.to_sym][name.to_sym] = attr.value
        end
      end

      @referenced_files << RMT::Rpm::FileEntry.new(
        hash[:location][:href],
        hash[:checksum][:type],
        hash[:checksum][:value],
        type
      )
    end
  end

end
