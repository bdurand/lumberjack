# frozen_string_literal: true

appraise "jruby" do
  # rdoc 8.0 (a dependency of irb) depends on rbs, which has native
  # extensions that do not build on JRuby.
  remove_gem "irb"
end
