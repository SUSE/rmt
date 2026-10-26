require 'rails_helper'

# Minimal structs declaring only the methods from Etc::Group & Etc::Passwd
# that RMT::CLI:Base.drop_privileges depends on.
GroupEntry = Struct.new(:gid)
PasswdEntry = Struct.new(:uid)

RSpec.describe RMT::CLI::Base do
  subject(:base) { described_class.new }


  describe '#needs_path' do
    before do
      # Make all protected methods public for testing purpose
      described_class.send(:public, :needs_path)
    end

    let(:test_paths) do
      [
        { path: '/foo/bar', expected: '/foo/bar' },
        { path: '/foo/bar/test/..', expected: '/foo/bar' },
        { path: '/foo/./bar', expected: '/foo/bar' }
      ]
    end

    it 'returns a normalised path' do
      allow(File).to receive(:directory?).and_return(true)
      test_paths.each do |test_case|
        expect(base.needs_path(test_case[:path])).to eq(test_case[:expected])
      end
    end

    it 'raises an exception if the path is not writeable' do
      allow(File).to receive(:directory?).and_return(true)
      allow(File).to receive(:writable?).and_return(false)

      expect { base.needs_path('/foo/bar', writable: true) }.to raise_error(RMT::CLI::Error, %r{/foo/bar is not writable by user})
    end

    it 'raises an exception if the file is not a directory' do
      allow(File).to receive(:directory?).and_return(false)

      expect { base.needs_path('/foo/bar') }.to raise_error(RMT::CLI::Error, %r{/foo/bar is not a directory})
    end
  end

  describe '.drop_privileges' do
    let(:rmt_gid) { 467 }
    let(:rmt_uid) { 467 }

    before do
      group_entry = GroupEntry.new(rmt_gid)
      passwd_entry = PasswdEntry.new(rmt_uid)
      allow(Etc).to receive(:getgrnam).with(RMT::DEFAULT_GROUP).and_return(group_entry)
      allow(Etc).to receive(:getpwnam).with(RMT::DEFAULT_USER).and_return(passwd_entry)
    end

    context 'when running as root' do
      before do
        allow(described_class).to receive(:process_user_name).and_return('root')
        # Stub actual privilege-changing syscalls to prevent side effects
        # that would leak into subsequent tests (e.g. changing the real UID).
        allow(Process::GID).to receive(:change_privilege)
        allow(Process::Sys).to receive(:setuid)
        allow(Process::Sys).to receive(:seteuid)
      end

      it 'calls Process::GID.change_privilege with the correct GID' do
        expect(Process::GID).to receive(:change_privilege).with(rmt_gid)
        described_class.drop_privileges
      end

      it 'does NOT call Process::Sys.setegid directly' do
        expect(Process::Sys).not_to receive(:setegid)
        described_class.drop_privileges
      end

      it 'calls Process::Sys.setuid and Process::Sys.seteuid' do
        expect(Process::Sys).to receive(:setuid).with(rmt_uid)
        expect(Process::Sys).to receive(:seteuid).with(rmt_uid)
        described_class.drop_privileges
      end
    end

    context 'when not running as root' do
      before do
        allow(described_class).to receive(:process_user_name).and_return('nginx')
      end

      it 'does not change any privileges' do
        expect(Process::GID).not_to receive(:change_privilege)
        expect(Process::Sys).not_to receive(:setuid)
        expect(Process::Sys).not_to receive(:seteuid)
        described_class.drop_privileges
      end
    end
  end
end
