# Make FakeFS play nicely with autoload
class Object

  class << self

    alias orig_const_missing const_missing
    def const_missing(*args)
      if FakeFS.activated?
        FakeFS.deactivate!
        result = orig_const_missing(*args)
        FakeFS.activate!
        result
      else
        orig_const_missing(*args)
      end
    end

  end

end
