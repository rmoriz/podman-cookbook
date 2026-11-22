# frozen_string_literal: true

# Chef 19 resolves `ChefPowerShell::PowerShellExceptions::PowerShellCommandFailed`
# in the rescue clause of its guard interpreter, but the gems Cinc ships for
# Linux do not include the chef-powershell gem. Without the constant a failing
# guard reports `NameError` and hides the real error. `Chef` is a class, so it
# has to be reopened as one.
class Chef
  unless const_defined?(:ChefPowerShell, false)
    module ChefPowerShell
      module PowerShellExceptions
        class PowerShellCommandFailed < StandardError; end
      end
    end
  end
end
