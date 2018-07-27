TestName = "Smoke_Test"
$:.unshift( File.join(File.dirname(__FILE__),'..',"adifyTest"))
$:.unshift(File.dirname(__FILE__))
require 'adifyTest.rb'
require 'adifySmokeTest.rb'
require 'adifyLogger.rb'
require 'new_smoke_test.rb'
## --- Initialization section ---
if ARGV.empty?
     env = 'PPE'
    # env = 'staging'
    # env = 'DEV'
    # env = 'QA'
    # env = 'PRODUCTION'
    # env = 'Sandbox'
    # env = 'Sandbox2'
  else
    env=ARGV[0]
  end

$CLEANUP = true
## $VERBOSE = true
## $DEBUG = true

# test = SmokeTest.new(env)
  test = SmokeTestNew.new(env)