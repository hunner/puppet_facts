require 'json'
require 'puppet'
# From puppet
require 'semver'

module PuppetFacts

  def set_pe_supported_platforms(metadata_format_hash)
    PuppetFacts.pe_supported_platforms
  end

  def available_pe_versions
    PuppetFacts.pe_versions
  end

  # Returns array of PE platforms for given PE version
  def available_pe_platforms(pe_version)
    PuppetFacts.pe_platforms[pe_version]
  end

  def on_pe_supported_platforms(targets='all')
    on_supported_platforms('pe', 'PE', targets)
  end

  def on_puppet_supported_platforms(targets='all')
    on_supported_platforms('puppet', '', targets)
  end

  # Returns a hash of filtered supported platforms
  #
  # @param [String] type the type of Puppet installation ('pe' or 'puppet')
  # @param [String] prefix the prefix for data directories (e.g. 'PE' or '')
  # @param [Array] targets the targets to filter on
  # @api public
  def on_supported_platforms(type, prefix, targets='all')
    on_platforms(true, type, prefix, targets='all')
  end

  def on_pe_unsupported_platforms(targets='all')
    on_unsupported_platforms('pe', 'PE', targets)
  end

  def on_puppet_unsupported_platforms(targets='all')
    on_unsupported_platforms('puppet', '', targets)
  end

  # We need the inverse, this is kind of ugly. I don't want to cram it into the
  # other method however.
  #
  # Returns a hash of filtered unsupported platforms
  #
  # @param [String] type the type of Puppet installation ('pe' or 'puppet')
  # @param [String] prefix the prefix for data directories (e.g. 'PE' or '')
  # @param [Array] targets the targets to filter on
  # @api public
  def on_unsupported_platforms(type, prefix, targets='all')
    on_platforms(false, type, prefix, targets='all')
  end

  # Returns a hash of filtered platforms
  #
  # @param [Boolean] supported filter on supported or unsupported platforms
  # @param [String] type the type of Puppet installation ('pe' or 'puppet')
  # @param [String] prefix the prefix for data directories (e.g. 'PE' or '')
  # @param [Array] targets the targets to filter on
  # @api public
  def on_platforms(supported, type, prefix, targets)
    targets = Array(targets)

    # TODO This should filter based on set_pe_supported_platforms
    facts = PuppetFacts.platform_facts(type, prefix)
    sup_facts = Hash.new
    facts.each do |ver,platforms|
      semver = "#{ver.sub(/^#{prefix}/,'')}.0"
      if SemVer[PuppetFacts.get_requirement(type)] === SemVer.new(semver)
        sup_facts[ver] = platforms.select do |platform, facts|
          if targets != ['all']
            if supported
              PuppetFacts.meta_supported_platforms.include?(platform) && targets.include?(platform)
            else
              ! PuppetFacts.meta_supported_platforms.include?(platform) && ! targets.include?(platform)
            end
          else
            if supported
              PuppetFacts.meta_supported_platforms.include?(platform)
            else
              ! PuppetFacts.meta_supported_platforms.include?(platform)
            end
          end
        end
      end
    end
    sup_facts
  end

  #private

  @proj_root = File.expand_path(File.join(File.dirname(__FILE__), '..'))
  if Dir[File.join(@proj_root,"PE*")].empty?
    fail(StandardError, "PE dir missing")
  end

  @data_dirs = Dir.glob(File.join(@proj_root, "/*")).select { |d| d =~ %r{/[^ \t/]*\d\.\d$} }
  @pe_dirs = @data_dirs.select { |d| d =~ %r{/PE\d\.\d} }

  # Returns array of PE versions
  def self.pe_versions
    @pe_versions ||= get_pe_versions
  end

  # @api private
  def self.get_pe_versions
    @pe_dirs.collect do |dir|
      File.basename(dir)
    end
  end

  # @api private
  def self.facts_paths(type, prefix)
    dir = @data_dirs.select { |d| d =~ %r{/#{prefix}\d\.\d} }
    @facts_path ||= {}
    @facts_path[type] ||= get_facts_paths(dir)
  end

  # @api private
  def self.get_facts_paths(dir)
    dir.collect do |dir|
      Dir[File.join(dir,"*")]
    end.flatten
  end

  # @api private
  def self.platform_facts(type, prefix)
    @platform_facts ||= {}
    @platform_facts[type] ||= get_platform_facts(type, prefix)
  end

  # @api private
  def self.get_platform_facts(type, prefix)
    facts_paths(type, prefix).inject({}) do |memo,file|
      platform = File.basename(file.gsub(/\.facts/, ''))
      version = File.basename(File.dirname(file))
      memo[version] = Hash.new unless memo[version]
      memo[version][platform] = Hash.new
      File.read(file).each_line do |line|
        key, value = line.split(' => ')
        memo[version][platform][key.to_sym] = value.chomp unless value.nil?
      end
      memo
    end
  end

  # @api private
  def self.meta_supported_platforms
    @meta_supported_platforms ||= get_meta_supported_platforms
  end

  # @api private
  def self.meta_to_facts(input)
    meta_to_facts = {
      'RedHat' => 'redhat',
      'CentOS' => 'centos',
      'Ubuntu' => 'ubuntu',
      'OracleLinux' => 'oracle',
      'SLES' => 'sles',
      'Scientific' => 'scientific',
      'Debian' => 'debian',
      '14.04' => '1404',
      '12.04' => '1204',
      '10.04' => '1004',
      '11 SP1' => '11',
    }
    ans = meta_to_facts[input]
    if ans
      ans
    else
      input
    end
  end

  # @api private
  def self.get_meta_supported_platforms
    metadata = get_metadata
    if metadata['operatingsystem_support'].nil?
      fail StandardError, "Unknown operatingsystem support"
    end
    os_sup = metadata['operatingsystem_support']

    os_sup.collect do |os_rel|
      os = meta_to_facts(os_rel['operatingsystem'])
      #os = meta_to_facts[os_sup['operatingsystem']]
      os_rel['operatingsystemrelease'].collect do |release|
        rel = meta_to_facts(release)
        [
          "#{os}-#{rel}-i386",
          "#{os}-#{rel}-x86_64"
        ]
      end
    end.flatten
  end

  # @api private
  def self.get_metadata
    if ! File.file?('metadata.json')
      fail StandardError, "Can't find metadata.json... dunno why"
    end
    metadata = JSON.parse(File.read('metadata.json'))
    if metadata.nil?
      fail StandardError, "Metadata is empty"
    end
    metadata
  end

  # @api private
  def self.get_requirement(type='pe')
    metadata = get_metadata
    if metadata['requirements'].nil?
      fail StandardError, 'No requirements in metadata'
    end
    requirement = metadata['requirements'].select do |x|
      x['name'] == type
    end
    if requirement.empty?
      fail StandardError, "No #{type} requirement found in metadata"
    end
    requirement.first['version_requirement']
  end
end
