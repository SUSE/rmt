require 'rails_helper'

describe RMT::Gpg do
  let(:metadata_file) { File.join(file_fixture('gpg'), 'dummy.xml') }
  let(:key_file) { File.join(file_fixture('gpg'), 'good.xml.key') }
  let(:signature_file) { File.join(file_fixture('gpg'), 'good.xml.asc') }
  let(:logger) { RMT::Logger.new('/dev/null') }

  let(:verifier) do
    described_class.new(
      metadata_file: metadata_file,
      key_file: key_file,
      signature_file: signature_file,
      logger: logger
    )
  end

  describe '#verify' do
    context 'when the signature is valid' do
      it 'returns true' do
        expect_any_instance_of(Tempfile).to receive(:unlink).and_call_original
        expect(verifier.verify_signature).to eq(true)
      end
    end

    context 'when the GPG key is invalid' do
      let(:key_file) { File.join(file_fixture('gpg'), 'bad.xml.key') }

      it 'raises an exception' do
        expect_any_instance_of(Tempfile).to receive(:unlink).and_call_original
        expect { verifier.verify_signature }.to raise_error(RMT::Gpg::Exception, 'GPG key import failed')
      end
    end

    context 'when the GPG signature is invalid' do
      let(:signature_file) { File.join(file_fixture('gpg'), 'bad.xml.asc') }

      it 'raises an exception' do
        expect_any_instance_of(Tempfile).to receive(:unlink).and_call_original
        expect { verifier.verify_signature }.to raise_error(RMT::Gpg::Exception, 'GPG signature verification failed')
      end
    end
  end
end
