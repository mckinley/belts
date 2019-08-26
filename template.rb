# rails app:template LOCATION=~/Projects/Belts/belts/template.rb

def create_base_setup
  say 'Creating base setup'
  create_base_dotfiles
  add_gems
  configure_application
end

def add_gems
  gem_group :development, :test do
    gem 'awesome_print'
    gem 'rspec-rails'
    gem 'factory_bot_rails'
    gem 'pry-rails'
    gem 'pry-byebug'
    gem 'bundler-audit', require: false
  end

  gem_group :development do
    gem 'spring-commands-rspec'
  end

  gem_group :test do
    gem 'launchy'
  end

  after_bundle do
    generate 'rspec:install'
    copy_file 'spec/support/system.rb', 'spec/support/system.rb'
    uncomment_lines 'spec/rails_helper.rb', 'each { |f| require f }'
  end
end

def configure_application
  application do
    <<-'RUBY'
    config.generators do |generate|
      generate.helper false
      generate.javascripts false
      generate.routing_specs false
      generate.stylesheets false
      generate.test_framework :rspec
      generate.view_specs false
      generate.controller_specs false
      generate.request_specs true
    end
    
    config.autoload_paths << "#{Rails.root}/lib"
    config.eager_load_paths << "#{Rails.root}/lib"
    RUBY
  end
end

def create_local_heroku_setup
  say 'Creating local Heroku setup'
  create_deploy_script
  create_review_apps_setup_script
  create_heroku_application_manifest_file
  configure_ci
end

def create_heroku_apps
  say 'Creating Heroku apps'
  create_staging_heroku_app options[:heroku_flags]
  create_production_heroku_app options[:heroku_flags]
  create_setup_script
  set_heroku_application_host
  set_heroku_rails_secrets
  set_heroku_backup_schedule
end

def create_base_dotfiles
  copy_file '.envrc'
  copy_file '.ruby-version'
end

def create_deploy_script
  copy_file 'bin/deploy', 'bin/deploy'

  instructions = <<~MARKDOWN

    ## Deploying

    If you have previously run the `./bin/setup` script,
    you can deploy to staging and production with:

        $ ./bin/deploy staging
        $ ./bin/deploy production
  MARKDOWN
  append_file 'README.md', instructions
  run 'chmod a+x bin/deploy'
end

def create_review_apps_setup_script
  template 'bin/setup-review-app.erb', 'bin/setup-review-app'
  run 'chmod a+x bin/setup-review-app'
end

def create_heroku_application_manifest_file
  template 'app.json.erb', 'app.json'
end

def configure_ci
  template '.circleci/config.yml.erb', '.circleci/circle.yml'
end

def create_staging_heroku_app(flags)
  app_name = heroku_app_name_for('staging')
  run_heroku_command "create #{app_name} #{flags}", 'staging'
end

def create_production_heroku_app(flags)
  app_name = heroku_app_name_for('production')
  run_heroku_command "create #{app_name} #{flags}", 'production'
end

def create_setup_script
  template 'bin/setup.erb', 'bin/setup', force: true
  run 'chmod a+x bin/setup'
end

def set_heroku_application_host
  %w(staging production).each do |environment|
    run_heroku_command(
      "config:add APPLICATION_HOST=#{heroku_app_name}-#{environment}.herokuapp.com",
      environment
    )
  end
end

def set_heroku_rails_secrets
  %w(staging production).each do |environment|
    run_heroku_command(
      "config:add SECRET_KEY_BASE=#{generate_secret}",
      environment
    )
  end
end

def set_heroku_backup_schedule
  %w(staging production).each do |environment|
    run_heroku_command(
      "pg:backups:schedule DATABASE_URL --at '10:00 UTC'",
      environment
    )
  end
end

def heroku_app_name
  app_name.dasherize
end

def heroku_app_name_for(environment)
  "#{heroku_app_name}-#{environment}"
end

def generate_secret
  SecureRandom.hex(64)
end

def run_heroku_command(command, environment)
  run("heroku #{command} --remote #{environment}")
end

def source_paths
  [(Pathname.new(__FILE__).dirname + 'lib').expand_path]
end

create_base_setup
create_local_heroku_setup
create_heroku_apps


after_bundle do
  git :init
  git add: '.'
  git commit: "-a -m 'Initial commit'"
end
