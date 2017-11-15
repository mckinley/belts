# rails app:template LOCATION=~/Projects/Belts/belts/template.rb

def create_base_setup
  say 'Creating base setup'
  create_base_dotfiles
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
  set_heroku_remotes
  set_heroku_application_host
  set_heroku_rails_secrets
  create_heroku_pipeline
end

def create_base_dotfiles
  copy_file '.envrc'
  copy_file '.ruby-version'
end

def create_deploy_script
  copy_file 'bin_deploy', 'bin/deploy'

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
  template(
    'bin_setup-review-app.erb',
    'bin/setup-review-app',
    force: true,
  )
  run 'chmod a+x bin/setup-review-app'
end

def create_heroku_application_manifest_file
  template 'app.json.erb', 'app.json'
end

def configure_ci
  copy_file 'circle.yml'
end

def create_staging_heroku_app(flags)
  app_name = heroku_app_name_for('staging')
  run_toolbelt_command "create #{app_name} #{flags}", 'staging'
end

def create_production_heroku_app(flags)
  app_name = heroku_app_name_for('production')
  run_toolbelt_command "create #{app_name} #{flags}", 'production'
end

def set_heroku_remotes
  remotes = <<~SHELL
    # Only if this isn't CI
    if [ -z "$CI" ]; then
    #{command_to_join_heroku_app('staging')}
    #{command_to_join_heroku_app('production')}
    fi
    git config heroku.remote staging
  SHELL
  append_file 'bin/setup', remotes
end

def set_heroku_application_host
  %w(staging production).each do |environment|
    run_toolbelt_command(
      "config:add APPLICATION_HOST=#{heroku_app_name}-#{environment}.herokuapp.com",
      environment
    )
  end
end

def set_heroku_rails_secrets
  %w(staging production).each do |environment|
    run_toolbelt_command(
      "config:add SECRET_KEY_BASE=#{generate_secret}",
      environment
    )
  end
end

def create_heroku_pipeline
  pipelines_plugin = `heroku help | grep pipelines`
  if pipelines_plugin.empty?
    puts 'You need heroku pipelines plugin. Run: brew upgrade heroku-toolbelt'
    exit 1
  end

  run_toolbelt_command(
    "pipelines:create #{heroku_app_name} -a #{heroku_app_name}-staging --stage staging",
    'staging'
  )

  run_toolbelt_command(
    "pipelines:add #{heroku_app_name} -a #{heroku_app_name}-production --stage production",
    'production'
  )
end

def command_to_join_heroku_app(environment)
  heroku_app_name = heroku_app_name_for(environment)
  <<~SHELL

    if heroku join --app #{heroku_app_name} > /dev/null 2>&1; then
      git remote add #{environment} git@heroku.com:#{heroku_app_name}.git || true
      printf 'You are a collaborator on the "#{heroku_app_name}" Heroku app\n'
    else
      printf 'Ask for access to the "#{heroku_app_name}" Heroku app\n'
    fi
  SHELL
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

def run_toolbelt_command(command, environment)
  run("heroku #{command} --remote #{environment}")
end

def source_paths
  [(Pathname.new(__FILE__).dirname + 'lib').expand_path]
end

create_base_setup
create_local_heroku_setup
create_heroku_apps



