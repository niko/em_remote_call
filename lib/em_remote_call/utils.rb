module EM::RemoteCall; end

class EM::RemoteCall::Utils
  
  def self.constantize(string)
    string.split('::').inject(Object){ |klass,str| klass.const_get(str) rescue false }
  end
  
end
