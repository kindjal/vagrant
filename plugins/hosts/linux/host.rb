require 'log4r'

require "vagrant"
require 'vagrant/util/platform'

module VagrantPlugins
  module HostLinux
    # Represents a Linux based host, such as Ubuntu.
    class Host < Vagrant.plugin("1", :host)
      include Vagrant::Util
      include Vagrant::Util::Retryable

      def self.match?
        Vagrant::Util::Platform.linux?
      end

      def self.precedence
        # Set a lower precedence because this is a generic OS. We
        # want specific distros to match first.
        2
      end

      def initialize(*args)
        super

        @logger = Log4r::Logger.new("vagrant::hosts::linux")
        @nfs_server_binary = "/etc/init.d/nfs-kernel-server"
      end

      def nfs?
        retryable(:tries => 10, :on => TypeError) do
          # Check procfs to see if NFSd is a supported filesystem
          system("cat /proc/filesystems | grep nfsd > /dev/null 2>&1")
        end
      end

      def nfs_export(id, ip, folders)
        @ui.info I18n.t("vagrant.hosts.linux.nfs_export")
        sleep 0.5

        # This should only ask for administrative permission once, even
        # though its executed in multiple subshells.
        folders.each do |name,opts|
          @logger.debug("sudo exportfs #{ip}:#{opts[:hostpath]}")
          system("sudo exportfs #{ip}:#{opts[:hostpath]}")
        end
      end

      def nfs_prune(valid_ids)
        # Since we used exportfs above, all modifications are to etab and
        # thus temporary.  Restarting nfsd flushes them.
        @logger.info("Pruning invalid NFS entries...")
        system("sudo #{@nfs_server_binary} restart")
      end
    end
  end
end
