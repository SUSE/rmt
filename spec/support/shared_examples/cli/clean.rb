shared_examples 'prints to stdout' do
  it 'prints a proper message to stdout' do
    expect { command }
      .to output(expected_output).to_stdout
      .and output('').to_stderr
  end
end

shared_examples 'does not remove files' do
  it 'does not remove any files' do
    silence_stdout do
      expect { command }
        .not_to change { Dir.glob(File.join(mirror_dir, '**', '*')).count }
    end
  end
end

shared_examples 'does not remove database entries' do
  it 'does not remove any database entries' do
    silence_stdout do
      expect { command }
        .not_to change(DownloadedFile, :count)
    end
  end
end

shared_examples 'removes files' do
  it 'removes all stale files' do
    silence_stdout do
      expect { command }
        .to change { Dir.glob(File.join(mirror_dir, '**', '*.*rpm')).count }
        .by(-stale_list.files.count - stale_list.hardlinks.count)
    end
  end
end

shared_examples 'removes database entries' do
  it 'removes all database entries referencing stale files' do
    silence_stdout do
      expect { command }
        .to change(DownloadedFile, :count)
        .by(-stale_list.db_entries.count)
    end
  end
end

shared_examples 'does not remove fresh stale files' do
  it 'does not remove fresh stale files' do
    silence_stdout do
      # File.stat will fail if the file doesn't exist, which come in hand in
      # case the implementation fails to keep the files.
      expect { command }.not_to change {
        fresh_stale_list.files.map { |f| File.stat(f[:file]).inspect }
      }
    end
  end
end

shared_examples 'does not remove database entries of fresh stale files' do
  it 'does not remove database entries referencing fresh stale files' do
    fresh_files = fresh_stale_list.db_entries.pluck(:file)
    silence_stdout do
      expect { command }.not_to change {
        DownloadedFile.where(local_path: fresh_files).pluck(:local_path)
      }.from(fresh_files)
    end
  end
end
