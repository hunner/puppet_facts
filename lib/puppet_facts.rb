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

  def on_pe_supported_platforms(targets=nil)
    targets = Array(targets) if targets

    # TODO This should filter based on set_pe_supported_platforms
    facts = PuppetFacts.pe_platform_facts
    sup_facts = Hash.new
    facts.each do |pe_ver,platforms|
      pe_semver = "#{pe_ver.sub(/^PE/,'')}.0"
      if SemVer[PuppetFacts.get_pe_requirement] === SemVer.new(pe_semver)
        sup_facts[pe_ver] = platforms.select do |platform, facts|
          if targets
            PuppetFacts.meta_supported_platforms.include?(platform) && targets.include?(platform)
          else
            PuppetFacts.meta_supported_platforms.include?(platform)
          end
        end
      end
    end
    sup_facts
  end

  # We need the inverse, this is kind of ugly. I don't want to cram it into the
  # other method however.
  def on_pe_unsupported_platforms(targets=nil)
    targets = Array(targets) if targets

    # TODO This should filter based on set_pe_supported_platforms
    facts = PuppetFacts.pe_platform_facts
    sup_facts = Hash.new
    facts.each do |pe_ver,platforms|
      pe_semver = "#{pe_ver.sub(/^PE/,'')}.0"
      if SemVer[PuppetFacts.get_pe_requirement] === SemVer.new(pe_semver)
        sup_facts[pe_ver] = platforms.select do |platform, facts|
          if targets
            ! PuppetFacts.meta_supported_platforms.include?(platform) && ! targets.include?(platform)
          else
            ! PuppetFacts.meta_supported_platforms.include?(platform)
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

  @pe_dirs = Dir[File.join(@proj_root,"PE*")]

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
  def self.pe_platforms
    @pe_platforms ||= get_pe_platforms
  end

  # @api private
  def self.get_pe_platforms
    @pe_dirs.inject({}) do |memo,pe_dir|
      pe_version = File.basename(pe_dir)
      if Dir[File.join(@proj_root,pe_version,"*")].empty?
        fail(StandardError, "Puppet facts missing for #{pe_version}")
      end
      memo[pe_version] = Dir[File.join(@proj_root,pe_version,"*")].collect do |facts|
        File.basename(facts.gsub(/\.facts/, ''))
      end
      memo
    end
  end

  # @api private
  def self.pe_facts_paths
    @pe_facts_paths ||= get_pe_facts_paths
  end

  # @api private
  def self.get_pe_facts_paths
    @pe_dirs.collect do |dir|
      Dir[File.join(dir,"*")]
    end.flatten
  end

  # @api private
  def self.pe_platform_facts
    @pe_platform_facts ||= get_pe_platform_facts
  end

  # @api private
  def self.get_pe_platform_facts
    pe_facts_paths.inject({}) do |memo,file|
      pe_platform = File.basename(file.gsub(/\.facts/, ''))
      pe_version = File.basename(File.dirname(file))
      memo[pe_version] = Hash.new unless memo[pe_version]
      memo[pe_version][pe_platform] = Hash.new
      File.read(file).each_line do |line|
        key, value = line.split(' => ')
        memo[pe_version][pe_platform][key.to_sym] = value.chomp unless value.nil?
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
  def self.get_pe_requirement
    metadata = get_metadata
    if metadata['requirements'].nil?
      fail StandardError, 'No requirements in metadata'
    end
    pe_requirement = metadata['requirements'].select do |x|
      x['name'] == 'pe'
    end
    if pe_requirement.empty?
      fail StandardError, 'No PE requirement found in metadata'
    end
    pe_requirement.first['version_requirement']
  end
end
