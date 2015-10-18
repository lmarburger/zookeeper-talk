namespace :zookeeper do
  version = "3.4.6"
  archive_file = "vendor/zookeeper-#{version}.tar.gz"
  unpacked_directory = "vendor/zookeeper-#{version}"
  mirror_root = 'http://mirror.tcpdiag.net/apache'

  file archive_file do
    unless system("which wget > /dev/null 2>&1")
      abort 'wget is not installed. Try `brew install wget`'
    end

    Dir.chdir "vendor" do
      sh "wget #{mirror_root}/zookeeper/zookeeper-#{version}/zookeeper-#{version}.tar.gz"
    end
  end

  directory unpacked_directory
  file "#{unpacked_directory}/bin" => unpacked_directory do
    Rake::Task[archive_file].invoke
    Dir.chdir "vendor" do
      sh "tar -zx --exclude '*/src/*' --exclude '*/contrib/*' --exclude '*/docs/*' -f zookeeper-#{version}.tar.gz"
    end
  end

  desc "Install zookeeper for development"
  task :install => "#{unpacked_directory}/bin"

  desc 'Start zookeeper for development'
  task :start => :install do
    pid_file = File.expand_path('tmp/pids/zookeeper.pid')

    if File.exists?(pid_file)
      begin
        Process.kill(0, File.read(pid_file).chomp.to_i)
        next
      rescue Errno::EPERM
        next
      rescue Errno::ESRCH
      end
    end

    ENV['ZOOCFGDIR']   = File.expand_path('config')
    ENV['ZOOPIDFILE']  = pid_file
    ENV['ZOO_LOG_DIR'] = File.expand_path('log')

    sh "#{unpacked_directory}/bin/zkServer.sh start zoo_development.cfg"
  end

  desc 'Stop zookeeper for development'
  task :stop do
    ENV['ZOOCFGDIR']   = File.expand_path('config')
    ENV['ZOOPIDFILE']  = File.expand_path('tmp/pids/zookeeper.pid')
    ENV['ZOO_LOG_DIR'] = File.expand_path('log')

    sh "#{unpacked_directory}/bin/zkServer.sh stop zoo_development.cfg"
  end
end
