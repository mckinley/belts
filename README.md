# belts

Sets up heroku apps for a rails project.

Run the following from an existing rails app:

```
rails app:template LOCATION=~/Projects/Belts/belts/template.rb
```

## Circle Ci

Use heroku rsa key in Lastpass
In Circle Ci Settings > Heroku Deployment
Set deploy user

## TODO:
add `config.autoload_paths << Rails.root.join('lib')` to config/application.rb
