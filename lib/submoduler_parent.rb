# frozen_string_literal: true

require_relative "submoduler_parent/version"
require_relative "submoduler_parent/cli"
require_relative "submoduler_parent/status_command"
require_relative "submoduler_parent/test_command"
require_relative "submoduler_parent/push_command"
require_relative "submoduler_parent/push_command"

module SubmodulerParent
  class Error < StandardError; end
end
