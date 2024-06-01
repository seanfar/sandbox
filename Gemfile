source 'https://rubygems.org'

gem 'fastlane'

# Cocoapods 1.15 introduced a bug which break the build. We will remove the upper
# bound in the template on Cocoapods with next React Native release.
gem 'activesupport', '>= 6.1.7.5', '< 7.1.0'
gem 'cocoapods', '>= 1.13', '< 1.15'

gem 'rubocop'

gem 'rqrcode'
gem 'slack-ruby-client'

plugins_path = File.join(File.dirname(__FILE__), 'fastlane', 'Pluginfile')
eval_gemfile(plugins_path) if File.exist?(plugins_path)
