![image](https://user-images.githubusercontent.com/1793699/51550703-31f63b80-1e6d-11e9-9600-cf6b527499a6.png)

# Developing RMT plugins

RMT plugins are implemented as Rails engines, that are distributed without packaging them as Ruby Gems.

1. Create the plugin:
```
rails plugin new example_plugin --mountable --skip-gemspec --skip-gemfile --skip-test --skip-gemfile-entry --api --skip-action-mailer --skip-active-record --skip-action-cable
```
2. Move the plugin into `engines` directory: `mv example_plugin/ engines/`, the engines
3. Remove unneeded files in `engines/example_plugin`, e.g.:
 * `rm lib/example_plugin/version.rb` -- plugins aren't versioned separately from main RMT package;
 * `rm MIT-LICENSE` -- unless the plugin actually has a separate license that's different from core RMT;
 * `rm -rf app/jobs/`
 * `rm -rf app/mailers/`
 * etc.
4. `lib/example_plugin.rb` is the entrypoint of the plugin. Due to the fact it is not a gem anymore, `engines/example_plugin/lib` is not in `$LOAD_PATH`, add a line at the top to add it:
```ruby
$LOAD_PATH.push File.expand_path(__dir__, '..')
```
5. When `lib/example_plugin.rb` is loaded, Rails isn't fully initialized yet (controllers/models/etc. aren't loaded). Code that adds filters or otherwise needs to modify existing RMT functionality most likely will have to go into `engines/example_plugin/lib/example_plugin/engine.rb`:

```ruby
module ExamplePlugin
  class Engine < ::Rails::Engine
    isolate_namespace ExamplePlugin
    config.generators.api_only = true

    # add this for `rails generate` to create RSpec skeletons
    config.generators do |g|
      g.test_framework :rspec
    end
    
    config.after_initialize do
      
      # At this point everything is loaded and you can add filters to base RMT controllers/models/etc.
      System.class_eval do
        after_commit :do_stuff

        def do_stuff
          raise 'Something happened!'
        end
      end
    end
  end
end
```
