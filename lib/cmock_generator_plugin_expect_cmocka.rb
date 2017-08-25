# ==========================================
#   CMock Project - Automatic Mock Generation for C
#   Copyright (c) 2007 Mike Karlesky, Mark VanderVoord, Greg Williams
#   [Released under MIT License. Please refer to license.txt for details]
# ==========================================

class CMockGeneratorPluginExpect

  attr_reader :priority
  attr_accessor :config, :utils, :unity_helper, :ordered

  def initialize(config, utils)
    @config       = config
    @ptr_handling = @config.when_ptr
    @ordered      = @config.enforce_strict_ordering
    @utils        = utils
    @unity_helper = @utils.helpers[:unity_helper]
    @priority     = 5

    if (@config.plugins.include? :expect_any_args)
      alias :mock_implementation :mock_implementation_might_check_args
    else
      alias :mock_implementation :mock_implementation_always_check_args
    end
  end

  def instance_typedefs(function)
    lines = ""
    lines << "  int CallOrder;\n"                          if (@ordered)
    function[:args].each do |arg|
      lines << "  #{arg[:type]} Expected_#{arg[:name]};\n"
    end
    lines
  end

  def mock_implementation_always_check_args(function)
    lines = ""
    function[:args].each do |arg|
      lines << @utils.code_verify_an_arg_expectation(function, arg)
    end
    lines
  end

  def mock_implementation_might_check_args(function)
    return "" if (function[:args].empty?)
    lines = "  if (cmock_call_instance->IgnoreMode != CMOCK_ARG_NONE)\n  {\n"
    function[:args].each do |arg|
      lines << @utils.code_verify_an_arg_expectation(function, arg)
    end
    lines << "\n  }\n"
    lines
  end

  def mock_verify(function)
    func_name = function[:name]
    "  assert_true(CMOCK_GUTS_NONE == Mock.#{func_name}_CallInstance);\n"
  end

end
