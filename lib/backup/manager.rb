module Backup
  class Manager
    ARCHIVES_TO_BACKUP = %w[uploads builds artifacts pages lfs registry]
    FOLDERS_TO_BACKUP = %w[repositories db]
    FILE_NAME_SUFFIX = '_gitlab_backup.tar'

    def pack
      # Make sure there is a connection
      ActiveRecord::Base.connection.reconnect!

      # saving additional informations
      s = {}
      s[:db_version]         = "#{ActiveRecord::Migrator.current_version}"
      s[:backup_created_at]  = Time.now
      s[:gitlab_version]     = Gitlab::VERSION
      s[:tar_version]        = tar_version
      s[:skipped]            = ENV["SKIP"]
      tar_file = "#{s[:backup_created_at].strftime('%s_%Y_%m_%d')}#{FILE_NAME_SUFFIX}"

      Dir.chdir(Gitlab.config.backup.path) do
        File.open("#{Gitlab.config.backup.path}/backup_information.yml",
                  "w+") do |file|
          file << s.to_yaml.gsub(/^---\n/,'')
        end

        # create archive
        $progress.print "Creating backup archive: #{tar_file} ... "
        # Set file permissions on open to prevent chmod races.
        tar_system_options = {out: [tar_file, 'w', Gitlab.config.backup.archive_permissions]}
        if Kernel.system('tar', '-cf', '-', *backup_contents, tar_system_options)
          $progress.puts "done".color(:green)
        else
          puts "creating archive #{tar_file} failed".color(:red)
          abort 'Backup failed'
        end

        upload(tar_file)
      end
    end

    def upload(tar_file)
      $progress.print "Uploading backup archive to remote storage #{remote_directory} ... "

      connection_settings = Gitlab.config.backup.upload.connection
      if connection_settings.blank?
        $progress.puts "skipped".color(:yellow)
        return
      end

      directory = connect_to_remote_directory(connection_settings)

      if directory.files.create(key: tar_file, body: File.open(tar_file), public: false,
          multipart_chunk_size: Gitlab.config.backup.upload.multipart_chunk_size,
          encryption: Gitlab.config.backup.upload.encryption)
        $progress.puts "done".color(:green)
      else
        puts "uploading backup to #{remote_directory} failed".color(:red)
        abort 'Backup failed'
      end
    end

    def cleanup
      $progress.print "Deleting tmp directories ... "

      backup_contents.each do |dir|
        next unless File.exist?(File.join(Gitlab.config.backup.path, dir))

        if FileUtils.rm_rf(File.join(Gitlab.config.backup.path, dir))
          $progress.puts "done".color(:green)
        else
          puts "deleting tmp directory '#{dir}' failed".color(:red)
          abort 'Backup failed'
        end
      end
    end

    def remove_old
      # delete backups
      $progress.print "Deleting old backups ... "
      keep_time = Gitlab.config.backup.keep_time.to_i

      if keep_time > 0
        removed = 0

        Dir.chdir(Gitlab.config.backup.path) do
          Dir.glob("*#{FILE_NAME_SUFFIX}").each do |file|
            next unless file =~ /(\d+)(?:_\d{4}_\d{2}_\d{2})?_gitlab_backup\.tar/

            timestamp = $1.to_i

            if Time.at(timestamp) < (Time.now - keep_time)
              begin
                FileUtils.rm(file)
                removed += 1
              rescue => e
                $progress.puts "Deleting #{file} failed: #{e.message}".color(:red)
              end
            end
          end
        end

        $progress.puts "done. (#{removed} removed)".color(:green)
      else
        $progress.puts "skipping".color(:yellow)
      end
    end

    def unpack
      Dir.chdir(Gitlab.config.backup.path)

      # check for existing backups in the backup dir
      file_list = Dir.glob("*#{FILE_NAME_SUFFIX}")

      if file_list.count == 0
        $progress.puts "No backups found in #{Gitlab.config.backup.path}"
        $progress.puts "Please make sure that file name ends with #{FILE_NAME_SUFFIX}"
        exit 1
      end

      if file_list.count > 1 && ENV["BACKUP"].nil?
        $progress.puts 'Found more than one backup, please specify which one you want to restore:'
        $progress.puts 'rake gitlab:backup:restore BACKUP=timestamp_of_backup'
        exit 1
      end

      if ENV['BACKUP'].present?
        tar_file = "#{ENV['BACKUP']}#{FILE_NAME_SUFFIX}"
      else
        tar_file = file_list.first
      end

      unless File.exist?(tar_file)
        $progress.puts "The backup file #{tar_file} does not exist!"
        exit 1
      end

      $progress.print 'Unpacking backup ... '

      unless Kernel.system(*%W(tar -xf #{tar_file}))
        $progress.puts 'unpacking backup failed'.color(:red)
        exit 1
      else
        $progress.puts 'done'.color(:green)
      end

      ENV["VERSION"] = "#{settings[:db_version]}" if settings[:db_version].to_i > 0

      # restoring mismatching backups can lead to unexpected problems
      if settings[:gitlab_version] != Gitlab::VERSION
        $progress.puts 'GitLab version mismatch:'.color(:red)
        $progress.puts "  Your current GitLab version (#{Gitlab::VERSION}) differs from the GitLab version in the backup!".color(:red)
        $progress.puts '  Please switch to the following version and try again:'.color(:red)
        $progress.puts "  version: #{settings[:gitlab_version]}".color(:red)
        $progress.puts
        $progress.puts "Hint: git checkout v#{settings[:gitlab_version]}"
        exit 1
      end
    end

    def tar_version
      tar_version, _ = Gitlab::Popen.popen(%W(tar --version))
      tar_version.force_encoding('locale').split("\n").first
    end

    def skipped?(item)
      settings[:skipped] && settings[:skipped].include?(item) || disabled_features.include?(item)
    end

    private

    def connect_to_remote_directory(connection_settings)
      connection = ::Fog::Storage.new(connection_settings)

      # We only attempt to create the directory for local backups. For AWS
      # and other cloud providers, we cannot guarantee the user will have
      # permission to create the bucket.
      if connection.service == ::Fog::Storage::Local
        connection.directories.create(key: remote_directory)
      else
        connection.directories.get(remote_directory)
      end
    end

    def remote_directory
      Gitlab.config.backup.upload.remote_directory
    end

    def backup_contents
      folders_to_backup + archives_to_backup + ["backup_information.yml"]
    end

    def archives_to_backup
      ARCHIVES_TO_BACKUP.map{ |name| (name + ".tar.gz") unless skipped?(name) }.compact
    end

    def folders_to_backup
      FOLDERS_TO_BACKUP.reject{ |name| skipped?(name) }
    end

    def disabled_features
      features = []
      features << 'registry' unless Gitlab.config.registry.enabled
      features
    end

    def settings
      @settings ||= YAML.load_file("backup_information.yml")
    end
  end
end
