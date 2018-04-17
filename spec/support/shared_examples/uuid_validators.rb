shared_examples_for 'model with UUID format validation on field' do |field|
  let(:uuid_format_message) { 'should be formatted as UUID' }

  it { is_expected.to allow_value('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa').for(field) }
  it { is_expected.to allow_value('00000000-0000-0000-0000-000000000000').for(field) }
  it { is_expected.to allow_value('F48AF167-f47C-4C67-974E-B502E48C3731').for(field) }

  it { is_expected.not_to allow_value('').for(field).with_message(uuid_format_message) }
  it { is_expected.not_to allow_value('a').for(field).with_message(uuid_format_message) }
  it { is_expected.not_to allow_value('f48af167d47c4c67974eb502e48c3731').for(field).with_message(uuid_format_message) }
  it { is_expected.not_to allow_value('0F48AF167-f47C-4C67-974E-B502E48C37310').for(field).with_message(uuid_format_message) }
  it { is_expected.not_to allow_value('F48AF167-f47C-4C67-974E-B502X48C3731').for(field).with_message(uuid_format_message) }
  it { is_expected.not_to allow_value('F48AF167-f47C-4C67-974E-B502E48C373').for(field).with_message(uuid_format_message) }
end

shared_examples_for 'model with UUID format validation and nil forcing' do |field|
  let(:uuid_format_message) { 'should be formatted as UUID' }

  it { is_expected.to allow_value('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa').for(field) }
  it { is_expected.to allow_value('00000000-0000-0000-0000-000000000000').for(field) }
  it { is_expected.to allow_value('F48AF167-f47C-4C67-974E-B502E48C3731').for(field) }
  it { is_expected.to allow_value('').for(field) }
  it { is_expected.to allow_value('a').for(field) }
  it { is_expected.to allow_value('f48af167d47c4c67974eb502e48c3731').for(field) }
end
