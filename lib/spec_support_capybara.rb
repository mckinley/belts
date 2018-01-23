require 'capybara/poltergeist'
Capybara.javascript_driver = :poltergeist

Capybara.register_driver :poltergeist do |app|
  Capybara::Poltergeist::Driver.new(app, {
    js_errors: true,
    timeout: 90
  })
end

def sos
  save_and_open_page
  save_and_open_screenshot
end
