#! /usr/bin/env ruby

require 'spec_helper'
require 'facter'

describe "Oregano::Util::Windows::Process", :if => Oregano.features.microsoft_windows?  do
  describe "as an admin" do
    it "should have the SeCreateSymbolicLinkPrivilege necessary to create symlinks on Vista / 2008+",
      :if => Facter.value(:kernelmajversion).to_f >= 6.0 && Oregano.features.microsoft_windows? do
      # this is a bit of a lame duck test since it requires running user to be admin
      # a better integration test would create a new user with the privilege and verify
      expect(Oregano::Util::Windows::User).to be_admin
      expect(Oregano::Util::Windows::Process.process_privilege_symlink?).to be_truthy
    end

    it "should not have the SeCreateSymbolicLinkPrivilege necessary to create symlinks on 2003 and earlier",
      :if => Facter.value(:kernelmajversion).to_f < 6.0 && Oregano.features.microsoft_windows? do
      expect(Oregano::Util::Windows::User).to be_admin
      expect(Oregano::Util::Windows::Process.process_privilege_symlink?).to be_falsey
    end

    it "should be able to lookup a standard Windows process privilege" do
      Oregano::Util::Windows::Process.lookup_privilege_value('SeShutdownPrivilege') do |luid|
        expect(luid).not_to be_nil
        expect(luid).to be_instance_of(Oregano::Util::Windows::Process::LUID)
      end
    end

    it "should raise an error for an unknown privilege name" do
      expect { Oregano::Util::Windows::Process.lookup_privilege_value('foo') }.to raise_error do |error|
        expect(error).to be_a(Oregano::Util::Windows::Error)
        expect(error.code).to eq(1313) # ERROR_NO_SUCH_PRIVILEGE
      end
    end
  end

  describe "when reading environment variables" do
    after :each do
      # spec\integration\test\test_helper_spec.rb calls set_environment_strings
      # after :all and thus needs access to the real APIs once again
      Oregano::Util::Windows::Process.unstub(:GetEnvironmentStringsW)
      Oregano::Util::Windows::Process.unstub(:FreeEnvironmentStringsW)
    end

    it "will ignore only keys or values with corrupt byte sequences" do
      arraydest = []
      Oregano::Util::Log.newdestination(Oregano::Test::LogCollector.new(arraydest))

      env_vars = {}

      # Create a UTF-16LE version of the below null separated environment string
      # "a=b\x00c=d\x00e=\xDD\xDD\x00f=g\x00\x00"
      env_var_block =
        "a=b\x00".encode(Encoding::UTF_16LE) +
        "c=d\x00".encode(Encoding::UTF_16LE) +
        'e='.encode(Encoding::UTF_16LE) + "\xDD\xDD".force_encoding(Encoding::UTF_16LE) + "\x00".encode(Encoding::UTF_16LE) +
        "f=g\x00\x00".encode(Encoding::UTF_16LE)

      env_var_block_bytes = env_var_block.bytes.to_a

      FFI::MemoryPointer.new(:byte, env_var_block_bytes.count) do |ptr|
        # uchar here is synonymous with byte
        ptr.put_array_of_uchar(0, env_var_block_bytes)

        # stub the block of memory that the Win32 API would typically return via pointer
        Oregano::Util::Windows::Process.expects(:GetEnvironmentStringsW).returns(ptr)
        # stub out the real API call to free memory, else process crashes
        Oregano::Util::Windows::Process.expects(:FreeEnvironmentStringsW)

        env_vars = Oregano::Util::Windows::Process.get_environment_strings
      end

      # based on corrupted memory, the e=\xDD\xDD should have been removed from the set
      expect(env_vars).to eq({'a' => 'b', 'c' => 'd', 'f' => 'g'})

      # and Oregano should emit a warning about it
      expect(arraydest.last.level).to eq(:warning)
      expect(arraydest.last.message).to eq("Discarding environment variable e=\uFFFD which contains invalid bytes")
    end
  end

  describe "when setting environment variables" do
    it "can properly handle env var values with = in them" do
      begin
        name = SecureRandom.uuid
        value = 'foo=bar'

        Oregano::Util::Windows::Process.set_environment_variable(name, value)

        env = Oregano::Util::Windows::Process.get_environment_strings

        expect(env[name]).to eq(value)
      ensure
        Oregano::Util::Windows::Process.set_environment_variable(name, nil)
      end
    end

    it "can properly handle empty env var values" do
      begin
        name = SecureRandom.uuid

        Oregano::Util::Windows::Process.set_environment_variable(name, '')

        env = Oregano::Util::Windows::Process.get_environment_strings

        expect(env[name]).to eq('')
      ensure
        Oregano::Util::Windows::Process.set_environment_variable(name, nil)
      end
    end
  end
end
