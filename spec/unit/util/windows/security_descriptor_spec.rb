#!/usr/bin/env ruby

require 'spec_helper'
require 'oregano/util/windows'

describe "Oregano::Util::Windows::SecurityDescriptor", :if => Oregano.features.microsoft_windows? do
  let(:system_sid) { Oregano::Util::Windows::SID::LocalSystem }
  let(:admins_sid) { Oregano::Util::Windows::SID::BuiltinAdministrators }
  let(:group_sid) { Oregano::Util::Windows::SID::Nobody }
  let(:new_sid)   { 'S-1-5-32-500-1-2-3' }

  def empty_dacl
    Oregano::Util::Windows::AccessControlList.new
  end

  def system_ace_dacl
    dacl = Oregano::Util::Windows::AccessControlList.new
    dacl.allow(system_sid, 0x1)
    dacl
  end

  context "owner" do
    it "changes the owner" do
      sd = Oregano::Util::Windows::SecurityDescriptor.new(system_sid, group_sid, system_ace_dacl)
      sd.owner = new_sid

      expect(sd.owner).to eq(new_sid)
    end

    it "performs a noop if the new owner is the same as the old one" do
      dacl = system_ace_dacl
      sd = Oregano::Util::Windows::SecurityDescriptor.new(system_sid, group_sid, dacl)
      sd.owner = sd.owner

      expect(sd.dacl.object_id).to eq(dacl.object_id)
    end

    it "prepends SYSTEM when security descriptor owner is no longer SYSTEM" do
      sd = Oregano::Util::Windows::SecurityDescriptor.new(system_sid, group_sid, system_ace_dacl)
      sd.owner = new_sid

      aces = sd.dacl.to_a
      expect(aces.size).to eq(2)
      expect(aces[0].sid).to eq(system_sid)
      expect(aces[1].sid).to eq(new_sid)
    end

    it "does not prepend SYSTEM when DACL already contains inherited SYSTEM ace" do
      sd = Oregano::Util::Windows::SecurityDescriptor.new(admins_sid, system_sid, empty_dacl)
      sd.dacl.allow(admins_sid, 0x1)
      sd.dacl.allow(system_sid, 0x1, Oregano::Util::Windows::AccessControlEntry::INHERITED_ACE)
      sd.owner = new_sid

      aces = sd.dacl.to_a
      expect(aces.size).to eq(2)
      expect(aces[0].sid).to eq(new_sid)
    end

    it "does not prepend SYSTEM when security descriptor owner wasn't SYSTEM" do
      sd = Oregano::Util::Windows::SecurityDescriptor.new(group_sid, group_sid, empty_dacl)
      sd.dacl.allow(group_sid, 0x1)
      sd.owner = new_sid

      aces = sd.dacl.to_a
      expect(aces.size).to eq(1)
      expect(aces[0].sid).to eq(new_sid)
    end
  end

  context "group" do
    it "changes the group" do
      sd = Oregano::Util::Windows::SecurityDescriptor.new(system_sid, group_sid, system_ace_dacl)
      sd.group = new_sid

      expect(sd.group).to eq(new_sid)
    end

    it "performs a noop if the new group is the same as the old one" do
      dacl = system_ace_dacl
      sd = Oregano::Util::Windows::SecurityDescriptor.new(system_sid, group_sid, dacl)
      sd.group = sd.group

      expect(sd.dacl.object_id).to eq(dacl.object_id)
    end

    it "prepends SYSTEM when security descriptor group is no longer SYSTEM" do
      sd = Oregano::Util::Windows::SecurityDescriptor.new(new_sid, system_sid, system_ace_dacl)
      sd.group = new_sid

      aces = sd.dacl.to_a
      expect(aces.size).to eq(2)
      expect(aces[0].sid).to eq(system_sid)
      expect(aces[1].sid).to eq(new_sid)
    end

    it "does not prepend SYSTEM when DACL already contains inherited SYSTEM ace" do
      sd = Oregano::Util::Windows::SecurityDescriptor.new(admins_sid, admins_sid, empty_dacl)
      sd.dacl.allow(admins_sid, 0x1)
      sd.dacl.allow(system_sid, 0x1, Oregano::Util::Windows::AccessControlEntry::INHERITED_ACE)
      sd.group = new_sid

      aces = sd.dacl.to_a
      expect(aces.size).to eq(2)
      expect(aces[0].sid).to eq(new_sid)
    end

    it "does not prepend SYSTEM when security descriptor group wasn't SYSTEM" do
      sd = Oregano::Util::Windows::SecurityDescriptor.new(group_sid, group_sid, empty_dacl)
      sd.dacl.allow(group_sid, 0x1)
      sd.group = new_sid

      aces = sd.dacl.to_a
      expect(aces.size).to eq(1)
      expect(aces[0].sid).to eq(new_sid)
    end
  end
end
