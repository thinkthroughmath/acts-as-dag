require "active_model"
require "active_record"

$LOAD_PATH.unshift(File.dirname(__FILE__))

require "dag/dag"
require "dag/columns"
require "dag/poly_columns"
require "dag/polymorphic"
require "dag/standard"
require "dag/edges"
require "dag/validators"
require "dag/check"

$LOAD_PATH.shift

if defined?(ActiveRecord::Base)
  ActiveRecord::Base.extend Dag
end
