RSpec::Matchers.define :file_reference_containing_path do |expected|
  match do |actual|
    actual.local_path.include?(expected)
  end

  failure_message do |actual|
    "expected that file path #{actual.local_path} would contain #{expected}"
  end
end

RSpec::Matchers.define :be_like_relative_path do |regex|
  match do |actual|
    actual.relative_path =~ regex
  end

  failure_message do |actual|
    "expected that file path #{actual.relative_path} would contain #{regex}"
  end
end

RSpec::Matchers.define :contain_records_like do |expected|
  match do |actual|
    record_struct = Struct.new(:local_path, :checksum, :checksum_type, :size)

    @actual = actual.map { |r| record_struct.new(r.local_path, r.checksum, r.checksum_type, r.size) }
    @expected = expected.map { |r| record_struct.new(r.local_path, r.checksum, r.checksum_type, r.size) }

    actual.all? do |record|
      expected.any? do |object|
        record.local_path == object.local_path &&
          record.checksum == object.checksum &&
          record.checksum_type == object.checksum_type &&
          record.size == object.size
      end
    end
  end

  failure_message do |actual|
    "expected that collection #{actual} would contain #{expected}"
  end

  diffable
end
