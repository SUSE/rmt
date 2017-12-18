require 'rails_helper'

# rubocop:disable Metrics/LineLength

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

  context 'md5' do
    context 'checksum is wrong' do
      it 'raises an exception' do
        expect do
          described_class.verify_checksum('MD5', '0xDEADBEEF', test_file_path)
        end.to raise_error(RMT::ChecksumVerifier::Exception, 'Checksum doesn\'t match')
      end
    end

    context 'checksum is correct' do
      it 'does not raises a exception' do
        expect do
          described_class.verify_checksum('MD5', '3858f62230ac3c915f300c664312c63f', test_file_path)
        end.not_to raise_error
      end

      it 'handles strange formatting of MD5' do
        expect do
          described_class.verify_checksum('Md5', '3858f62230ac3c915f300c664312c63f', test_file_path)
        end.not_to raise_error
      end
    end
  end

  context 'sha1' do
    context 'checksum is wrong' do
      it 'raises an exception' do
        expect do
          described_class.verify_checksum('SHA1', '0xDEADBEEF', test_file_path)
        end.to raise_error(RMT::ChecksumVerifier::Exception, 'Checksum doesn\'t match')
      end
    end

    context 'checksum is correct' do
      it 'handles SHA -> SHA1' do
        expect do
          described_class.verify_checksum('SHA', '8843d7f92416211de9ebb963ff4ce28125932878', test_file_path)
        end.not_to raise_error
      end

      it 'does not raises a exception' do
        expect do
          described_class.verify_checksum('SHA1', '8843d7f92416211de9ebb963ff4ce28125932878', test_file_path)
        end.not_to raise_error
      end

      it 'handles strange formatting of SHA1' do
        expect do
          described_class.verify_checksum('ShA1', '8843d7f92416211de9ebb963ff4ce28125932878', test_file_path)
        end.not_to raise_error
      end
    end
  end

  context 'sha256' do
    context 'checksum is wrong' do
      it 'raises an exception' do
        expect do
          described_class.verify_checksum('SHA256', '0xDEADBEEF', test_file_path)
        end.to raise_error(RMT::ChecksumVerifier::Exception, 'Checksum doesn\'t match')
      end
    end

    context 'checksum is correct' do
      it 'does not raises a exception' do
        expect do
          described_class.verify_checksum('SHA256',
                                          'c3ab8ff13720e8ad9047dd39466b3c8974e592c2fa383d4a3960714caef0c4f2',
                                          test_file_path)
        end.not_to raise_error
      end

      it 'handles strange formatting of SHA256' do
        expect do
          described_class.verify_checksum('ShA256',
                                          'c3ab8ff13720e8ad9047dd39466b3c8974e592c2fa383d4a3960714caef0c4f2',
                                          test_file_path)
        end.not_to raise_error
      end
    end
  end

  context 'sha384' do
    context 'checksum is wrong' do
      it 'raises an exception' do
        expect do
          described_class.verify_checksum('SHA384', '0xDEADBEEF', test_file_path)
        end.to raise_error(RMT::ChecksumVerifier::Exception, 'Checksum doesn\'t match')
      end
    end

    context 'checksum is correct' do
      it 'does not raises a exception' do
        expect do
          described_class.verify_checksum('SHA384',
                                          '3c9c30d9f665e74d515c842960d4a451c83a0125fd3de7392d7b37231af10c72ea58aedfcdf89a5765bf902af93ecf06',
                                          test_file_path)
        end.not_to raise_error
      end

      it 'handles strange formatting of SHA256' do
        expect do
          described_class.verify_checksum('ShA384',
                                          '3c9c30d9f665e74d515c842960d4a451c83a0125fd3de7392d7b37231af10c72ea58aedfcdf89a5765bf902af93ecf06',
                                          test_file_path)
        end.not_to raise_error
      end
    end
  end

  context 'sha512' do
    context 'checksum is wrong' do
      it 'raises an exception' do
        expect do
          described_class.verify_checksum('SHA512', '0xDEADBEEF', test_file_path)
        end.to raise_error(RMT::ChecksumVerifier::Exception, 'Checksum doesn\'t match')
      end
    end

    context 'checksum is correct' do
      it 'does not raises a exception' do
        expect do
          described_class.verify_checksum('SHA512',
                                          '0a50261ebd1a390fed2bf326f2673c145582a6342d523204973d0219337f81616a8069b012587cf5635f6925f1b56c360230c19b273500ee013e030601bf2425',
                                          test_file_path)
        end.not_to raise_error
      end

      it 'handles strange formatting of SHA256' do
        expect do
          described_class.verify_checksum('ShA512',
                                          '0a50261ebd1a390fed2bf326f2673c145582a6342d523204973d0219337f81616a8069b012587cf5635f6925f1b56c360230c19b273500ee013e030601bf2425',
                                          test_file_path)
        end.not_to raise_error
      end
    end
  end
end
