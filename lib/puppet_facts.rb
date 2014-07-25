module PuppetFacts

  def set_pe_supported_platforms
  end

  def on_pe_supported_platforms
    Dir["../PE*"].inject({}) do |memo,pe_version|

      if Dir["../#{pe_version}/*"].empty?
        fail(StandardError, "Puppet facts missing")
      end

      memo[pe_version] = Dir["../#{pe_version}/*"].inject({}) do |hash,facts|
        platform_name = File.basename(facts.gsub(/\.facts/, ''))
        hash[platform_name] = Hash.new
        File.read(facts).each_line do |line|
          key, value = line.split(' => ')
          hash[platform_name][key.to_sym] = value.chomp unless value.nil?
        end
      end
    end
  end

end
