require 'rails_helper'

RSpec.describe RMT::ChecksumVerifier do
  let(:test_file_path) { file_fixture('checksum_verifier/file') }
  let(:test_file_content) { file_fixture('checksum_verifier/file').read }

  it('has the content foobar') { expect(test_file_content).to eq('foobar') }

  context 'hash function is unknown' do
    it 'raises an exception' do
      expect do
        described_class.verify_checksum('CHUNKYBACON42', '0xDEADBEEF', test_file_path)
      end.to raise_error(RMT::ChecksumVerifier::Exception, 'Unknown hash function CHUNKYBACON42')
    end
  end

  context 'defaults' do
    it 'handles SHA -> SHA1' do
      expect do
        described_class.verify_checksum('SHA', '8843d7f92416211de9ebb963ff4ce28125932878', test_file_path)
      end.not_to raise_error
    end
  end

  [
    {
      checksum_type: 'MD5',
      checksum_type_variants: %w[MD5 md5 mD5],
      checksum: '3858f62230ac3c915f300c664312c63f'
    },
    {
      checksum_type: 'SHA1',
      checksum_type_variants: %w[SHA1 sha1 ShA1],
      checksum: '8843d7f92416211de9ebb963ff4ce28125932878'
    },
    {
      checksum_type: 'SHA256',
      checksum_type_variants: %w[SHA256 sha256 ShA256],
      checksum: 'c3ab8ff13720e8ad9047dd39466b3c8974e592c2fa383d4a3960714caef0c4f2'
    },
    {
      checksum_type: 'SHA384',
      checksum_type_variants: %w[SHA384 sha384 ShA384],
      checksum: '3c9c30d9f665e74d515c842960d4a451c83a0125fd3de7392d7b37231af10c72ea58aedfcdf89a5765bf902af93ecf06'
    },
    {
      checksum_type: 'SHA512',
      checksum_type_variants: %w[SHA512 sha512 ShA512],
      checksum: '0a50261ebd1a390fed2bf326f2673c145582a6342d523204973d0219337f81616a8069b012587cf5635f6925f1b56c360230c19b273500ee013e030601bf2425'
    }
  ].each do |test_data|
    context test_data[:checksum_type] do
      context 'checksum is wrong' do
        it 'raises an exception' do
          expect do
            described_class.verify_checksum(test_data[:checksum_type], '0xDEADBEEF', test_file_path)
          end.to raise_error(RMT::ChecksumVerifier::Exception, 'Checksum doesn\'t match')
        end
      end

      context 'checksum is correct' do
        test_data[:checksum_type_variants].each do |checksum_type|
          it "does not raises a exception for checksum type - #{checksum_type}" do
            expect do
              described_class.verify_checksum(checksum_type, test_data[:checksum], test_file_path)
            end.not_to raise_error
          end
        end
      end
    end
  end
end
