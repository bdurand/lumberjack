require 'socket'
require 'digest'
require 'thread'

module Lumberjack
  # This class allows you to create 12 byte unique identifiers.
  class UniqueIdentifier
    @@lock  = Mutex.new
    @@index = 0
    @@host_key = Digest::MD5.digest(Socket.gethostname)[0, 3]
    
    LONG_BIG_ENDIAN = "N".freeze
    SHORT_BIG_ENDIAN = "n".freeze
    UNSIGNED_12_BYTE = "C12".freeze
    
    def initialize
      # 4 bytes current time
      oid = [Time.new.to_i].pack(LONG_BIG_ENDIAN)
      # 3 bytes machine
      oid << @@host_key
      # 2 bytes pid
      oid << [$$ % 0xFFFF].pack(SHORT_BIG_ENDIAN)
      # 3 bytes counter
      oid << [increment].pack(LONG_BIG_ENDIAN)[1, 3]
      @bytes = oid.unpack(UNSIGNED_12_BYTE)
    end
    
    def to_s
      @bytes.collect{|b| b < 16 ? "0#{b.to_s(16)}" : b.to_s(16)}.join.upcase
    end
    
    def to_a
      @bytes.dup
    end

    private
    
    def increment
      @@lock.synchronize do
        @@index = (@@index + 1) % 0xFFFFFF
      end
    end
  end
end