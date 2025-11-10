shared_context 'profile sets' do
  # profile set a1 variants
  let(:profile_set_a1) do
    { mod_list: { identifier: 'mod_a1_id', data: 'mod_a1_data' },
      pci_data: { identifier: 'pci_a1_id', data: 'pci_a1_data' } }
  end
  let(:profile_set_a1_no_ident) do
    profile_set_a1.transform_values do |profile|
      profile.reject { |key, _| key == :identifier }
    end
  end
  let(:profile_set_a1_no_data) do
    profile_set_a1.transform_values do |profile|
      profile.reject { |key, _| key == :data }
    end
  end

  # profile set a2 variants
  let(:profile_set_a2) do
    { mod_list: { identifier: 'mod_a2_id', data: 'mod_a2_data' },
      pci_data: { identifier: 'pci_a2_id', data: 'pci_a2_data' } }
  end
  let(:profile_set_a2_no_ident) do
    profile_set_a2.transform_values do |profile|
      profile.reject { |key, _| key == :identifier }
    end
  end

  # profile set b variants
  let(:profile_set_b) do
    { pkg_list: { identifier: 'pkg_id', data: 'pkg_data' } }
  end
  let(:profile_set_b_no_ident) do
    profile_set_b.transform_values do |profile|
      profile.reject { |key, _| key == :identifier }
    end
  end
  let(:profile_set_b_no_data) do
    profile_set_b.transform_values do |profile|
      profile.reject { |key, _| key == :data }
    end
  end

  # profile set c variants
  let(:profile_set_c) do
    { tst_data: { identifier: 'tst_id', data: 'tst_data' } }
  end
  let(:profile_set_c_no_ident) do
    profile_set_c.transform_values do |profile|
      profile.reject { |key, _| key == :identifier }
    end
  end
  let(:profile_set_c_no_data) do
    profile_set_c.transform_values do |profile|
      profile.reject { |key, _| key == :data }
    end
  end

  # profile set all valid and complete
  let(:profile_set_all) do
    profile_set_a1.merge(profile_set_b.merge(profile_set_c))
  end

  # profile set mixed
  let(:profile_set_mixed_complete) { profile_set_a1 }
  let(:profile_set_mixed_incomplete) { profile_set_b_no_data }
  let(:profile_set_mixed_incomplete_full) { profile_set_b }
  let(:profile_set_mixed_invalid) { profile_set_c_no_ident }
  let(:profile_set_mixed) do
    profile_set_mixed_complete.merge(profile_set_mixed_incomplete.merge(profile_set_mixed_invalid))
  end
  let(:profile_set_mixed_valid) { profile_set_mixed_complete.merge(profile_set_mixed_incomplete_full) }
end
