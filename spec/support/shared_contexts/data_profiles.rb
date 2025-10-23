shared_context 'data profile sets' do
  # data_profile_a1
  let(:data_profiles_a1) do
    { mod: { profileId: 'mod_a1_id', profileData: 'mod_a1_data' },
      pci: { profileId: 'pci_a1_id', profileData: 'pci_a1_data' } }
  end
  let(:data_profiles_a1_no_id) do
    data_profiles_a1.transform_values do |dp|
      dp.reject { |key, _| key == :profileId }
    end
  end
  let(:data_profiles_a1_no_data) do
    data_profiles_a1.transform_values do |dp|
      dp.reject { |key, _| key == :profileData }
    end
  end

  # data_profile_a2
  let(:data_profiles_a2) do
    { mod: { profileId: 'mod_a2_id', profileData: 'mod_a2_data' },
      pci: { profileId: 'pci_a2_id', profileData: 'pci_a2_data' } }
  end
  let(:data_profiles_a2_no_data) do
    data_profiles_a2.transform_values do |dp|
      dp.reject { |key, _| key == :profileData }
    end
  end

  # data_profile_b
  let(:data_profiles_b) do
    { pkg: { profileId: 'pkg_id', profileData: 'pkg_data' } }
  end
  let(:data_profiles_b_no_data) do
    data_profiles_b.transform_values do |dp|
      dp.reject { |key, _| key == :profileData }
    end
  end
end
